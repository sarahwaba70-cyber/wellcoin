;; Wellness Activity Tracker Contract
;; Tracks and verifies wellness activities to distribute WELL token rewards
;; Integrates with wellness-token contract for reward distribution

;; =========================
;; Constants
;; =========================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u200))
(define-constant ERR-UNAUTHORIZED (err u201))
(define-constant ERR-ACTIVITY-NOT-FOUND (err u202))
(define-constant ERR-INVALID-ACTIVITY-TYPE (err u203))
(define-constant ERR-INVALID-DURATION (err u204))
(define-constant ERR-INVALID-INTENSITY (err u205))
(define-constant ERR-ALREADY-VERIFIED (err u206))
(define-constant ERR-ALREADY-CLAIMED (err u207))
(define-constant ERR-VERIFICATION-EXPIRED (err u208))
(define-constant ERR-DAILY-LIMIT-EXCEEDED (err u209))
(define-constant ERR-USER-NOT-REGISTERED (err u210))

;; Activity types and their base rewards
(define-constant CARDIO "cardio")
(define-constant STRENGTH "strength")
(define-constant YOGA "yoga")
(define-constant MEDITATION "meditation")
(define-constant NUTRITION "nutrition")
(define-constant SLEEP "sleep")
(define-constant CHECKUP "checkup")

;; Base reward amounts (in micro-WELL tokens)
(define-constant CARDIO-REWARD u10000000) ;; 10 WELL
(define-constant STRENGTH-REWARD u15000000) ;; 15 WELL
(define-constant YOGA-REWARD u8000000) ;; 8 WELL
(define-constant MEDITATION-REWARD u8000000) ;; 8 WELL
(define-constant NUTRITION-REWARD u5000000) ;; 5 WELL
(define-constant SLEEP-REWARD u12000000) ;; 12 WELL
(define-constant CHECKUP-REWARD u50000000) ;; 50 WELL

;; Activity verification constants
(define-constant MIN-DURATION u5) ;; minimum 5 minutes
(define-constant MAX-DURATION u480) ;; maximum 8 hours
(define-constant MIN-INTENSITY u1) ;; intensity scale 1-10
(define-constant MAX-INTENSITY u10)
(define-constant VERIFICATION-WINDOW u1440) ;; 24 hours in blocks (~10 min blocks)
(define-constant MAX-DAILY-ACTIVITIES u10) ;; max activities per day per user

;; =========================
;; Data Variables
;; =========================

(define-data-var next-activity-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var wellness-token-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.wellness-token)

;; =========================
;; Data Maps
;; =========================

;; Activity records
(define-map activities 
  uint ;; activity-id
  {
    user: principal,
    activity-type: (string-ascii 20),
    duration: uint, ;; in minutes
    intensity: uint, ;; 1-10 scale
    timestamp: uint, ;; block height when logged
    is-verified: bool,
    is-claimed: bool,
    verification-deadline: uint,
    calculated-reward: uint
  }
)

;; User activity statistics
(define-map user-stats
  principal
  {
    total-activities: uint,
    total-rewards-earned: uint,
    current-streak: uint,
    longest-streak: uint,
    last-activity-block: uint,
    activities-today: uint,
    last-daily-reset: uint
  }
)

;; Daily activity tracking
(define-map daily-activities
  {user: principal, day: uint} ;; day = block-height / 144
  {activity-count: uint, total-duration: uint}
)

;; Verification privileges
(define-map verifiers principal bool)

;; Activity type validation
(define-map valid-activity-types (string-ascii 20) bool)

;; =========================
;; Private Functions
;; =========================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-verifier (user principal))
  (default-to false (map-get? verifiers user))
)

(define-private (get-current-day)
  (/ stacks-block-height u144) ;; Assuming ~144 blocks per day
)

(define-private (get-user-stats (user principal))
  (default-to 
    {total-activities: u0, total-rewards-earned: u0, current-streak: u0, 
     longest-streak: u0, last-activity-block: u0, activities-today: u0, last-daily-reset: u0}
    (map-get? user-stats user)
  )
)

(define-private (is-valid-activity-type (activity-type (string-ascii 20)))
  (default-to false (map-get? valid-activity-types activity-type))
)

(define-private (calculate-base-reward (activity-type (string-ascii 20)))
  (if (is-eq activity-type CARDIO) CARDIO-REWARD
    (if (is-eq activity-type STRENGTH) STRENGTH-REWARD
      (if (is-eq activity-type YOGA) YOGA-REWARD
        (if (is-eq activity-type MEDITATION) MEDITATION-REWARD
          (if (is-eq activity-type NUTRITION) NUTRITION-REWARD
            (if (is-eq activity-type SLEEP) SLEEP-REWARD
              (if (is-eq activity-type CHECKUP) CHECKUP-REWARD
                u0
              )
            )
          )
        )
      )
    )
  )
)

(define-private (calculate-duration-bonus (duration uint) (base-reward uint))
  (if (>= duration u30)
    (+ base-reward (/ base-reward u2)) ;; 50% bonus for 30+ minutes
    (if (>= duration u15)
      (+ base-reward (/ base-reward u4)) ;; 25% bonus for 15+ minutes
      base-reward
    )
  )
)

(define-private (calculate-intensity-bonus (intensity uint) (base-reward uint))
  (if (>= intensity u8)
    (+ base-reward (/ base-reward u5)) ;; 20% bonus for high intensity
    (if (>= intensity u6)
      (+ base-reward (/ base-reward u10)) ;; 10% bonus for moderate intensity
      base-reward
    )
  )
)

(define-private (update-user-streak (user principal) (current-block uint))
  (let 
    (
      (stats (get-user-stats user))
      (last-block (get last-activity-block stats))
      (current-streak (get current-streak stats))
    )
    
    ;; Check if activity is within streak window (within 2 days)
    (let 
      (
        (new-streak (if (< (- current-block last-block) u288) ;; 288 blocks ~ 2 days
                      (+ current-streak u1)
                      u1))
      )
      
      (map-set user-stats user 
        (merge stats 
          {
            current-streak: new-streak,
            longest-streak: (if (> new-streak (get longest-streak stats))
                             new-streak
                             (get longest-streak stats)),
            last-activity-block: current-block
          }
        )
      )
      new-streak
    )
  )
)

;; =========================
;; Public Functions
;; =========================

;; Log a new wellness activity
(define-public (log-activity (activity-type (string-ascii 20)) (duration uint) (intensity uint))
  (begin
    (asserts! (not (var-get contract-paused)) (err u211))
    (asserts! (is-valid-activity-type activity-type) ERR-INVALID-ACTIVITY-TYPE)
    (asserts! (and (>= duration MIN-DURATION) (<= duration MAX-DURATION)) ERR-INVALID-DURATION)
    (asserts! (and (>= intensity MIN-INTENSITY) (<= intensity MAX-INTENSITY)) ERR-INVALID-INTENSITY)
    
    (let 
      (
        (activity-id (var-get next-activity-id))
        (current-block stacks-block-height)
        (user-data (get-user-stats tx-sender))
        (current-day (get-current-day))
        (base-reward (calculate-base-reward activity-type))
        (duration-bonus (calculate-duration-bonus duration base-reward))
        (final-reward (calculate-intensity-bonus intensity duration-bonus))
      )
      
      ;; Check daily activity limit
      (asserts! (< (get activities-today user-data) MAX-DAILY-ACTIVITIES) ERR-DAILY-LIMIT-EXCEEDED)
      
      ;; Create activity record
      (map-set activities activity-id
        {
          user: tx-sender,
          activity-type: activity-type,
          duration: duration,
          intensity: intensity,
          timestamp: current-block,
          is-verified: false,
          is-claimed: false,
          verification-deadline: (+ current-block VERIFICATION-WINDOW),
          calculated-reward: final-reward
        }
      )
      
      ;; Update user statistics
      (let ((new-streak (update-user-streak tx-sender current-block)))
        (map-set user-stats tx-sender
          (merge user-data 
            {
              total-activities: (+ (get total-activities user-data) u1),
              activities-today: (if (is-eq (get last-daily-reset user-data) current-day)
                                 (+ (get activities-today user-data) u1)
                                 u1),
              last-daily-reset: current-day
            }
          )
        )
      )
      
      ;; Update daily tracking
      (let ((daily-data (default-to {activity-count: u0, total-duration: u0} 
                          (map-get? daily-activities {user: tx-sender, day: current-day}))))
        (map-set daily-activities {user: tx-sender, day: current-day}
          {
            activity-count: (+ (get activity-count daily-data) u1),
            total-duration: (+ (get total-duration daily-data) duration)
          }
        )
      )
      
      ;; Increment next activity ID
      (var-set next-activity-id (+ activity-id u1))
      
      (print {action: "activity-logged", activity-id: activity-id, user: tx-sender, type: activity-type, reward: final-reward})
      (ok activity-id)
    )
  )
)

;; Verify an activity (can be called by verifiers or auto-verified after 24 hours)
(define-public (verify-activity (activity-id uint))
  (let ((activity (unwrap! (map-get? activities activity-id) ERR-ACTIVITY-NOT-FOUND)))
    (asserts! (not (get is-verified activity)) ERR-ALREADY-VERIFIED)
    (asserts! (<= stacks-block-height (get verification-deadline activity)) ERR-VERIFICATION-EXPIRED)
    
    ;; Can be verified by: verifier, contract owner, or user after 24 hours
    (asserts! (or 
                (is-verifier tx-sender)
                (is-contract-owner)
                (and 
                  (is-eq tx-sender (get user activity))
                  (>= stacks-block-height (+ (get timestamp activity) u144))
                )
              ) ERR-UNAUTHORIZED)
    
    ;; Mark as verified
    (map-set activities activity-id 
      (merge activity {is-verified: true})
    )
    
    (print {action: "activity-verified", activity-id: activity-id, verifier: tx-sender})
    (ok true)
  )
)

;; Claim reward for a verified activity
(define-public (claim-activity-reward (activity-id uint))
  (let ((activity (unwrap! (map-get? activities activity-id) ERR-ACTIVITY-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get user activity)) ERR-UNAUTHORIZED)
    (asserts! (get is-verified activity) ERR-UNAUTHORIZED)
    (asserts! (not (get is-claimed activity)) ERR-ALREADY-CLAIMED)
    
    ;; Mark as claimed
    (map-set activities activity-id 
      (merge activity {is-claimed: true})
    )
    
    ;; Update user total rewards
    (let ((user-data (get-user-stats tx-sender)))
      (map-set user-stats tx-sender
        (merge user-data 
          {total-rewards-earned: (+ (get total-rewards-earned user-data) (get calculated-reward activity))}
        )
      )
    )
    
    (print {action: "reward-claimed", activity-id: activity-id, user: tx-sender, amount: (get calculated-reward activity)})
    (ok (get calculated-reward activity))
  )
)

;; =========================
;; Read-Only Functions
;; =========================

;; Get activity details
(define-read-only (get-activity (activity-id uint))
  (map-get? activities activity-id)
)

;; Get user statistics
(define-read-only (get-user-statistics (user principal))
  (ok (get-user-stats user))
)

;; Get user's activities (paginated)
(define-read-only (get-user-activities (user principal))
  (ok (get-user-stats user))
)

;; Get daily activity summary
(define-read-only (get-daily-summary (user principal) (day uint))
  (ok (default-to {activity-count: u0, total-duration: u0} 
        (map-get? daily-activities {user: user, day: day})))
)

;; Calculate potential reward for activity parameters
(define-read-only (calculate-reward (activity-type (string-ascii 20)) (duration uint) (intensity uint))
  (let 
    (
      (base-reward (calculate-base-reward activity-type))
      (duration-bonus (calculate-duration-bonus duration base-reward))
      (final-reward (calculate-intensity-bonus intensity duration-bonus))
    )
    (ok final-reward)
  )
)

;; =========================
;; Admin Functions
;; =========================

;; Add verifier privileges
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (map-set verifiers verifier true)
    (print {action: "verifier-added", verifier: verifier})
    (ok true)
  )
)

;; Remove verifier privileges
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (map-delete verifiers verifier)
    (print {action: "verifier-removed", verifier: verifier})
    (ok true)
  )
)

;; Toggle contract pause state
(define-public (toggle-pause)
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; =========================
;; Initialization
;; =========================

;; Initialize valid activity types
(map-set valid-activity-types CARDIO true)
(map-set valid-activity-types STRENGTH true)
(map-set valid-activity-types YOGA true)
(map-set valid-activity-types MEDITATION true)
(map-set valid-activity-types NUTRITION true)
(map-set valid-activity-types SLEEP true)
(map-set valid-activity-types CHECKUP true)

