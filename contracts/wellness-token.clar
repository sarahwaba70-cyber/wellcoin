;; Wellness Token (WELL) - SIP-010 Compliant Fungible Token
;; A wellness reward token that incentivizes healthy lifestyle activities
;; Users earn WELL tokens by completing verified wellness activities

;; =========================
;; Constants
;; =========================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-RECIPIENT (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-UNAUTHORIZED (err u105))
(define-constant ERR-ALREADY-REGISTERED (err u106))
(define-constant ERR-NOT-REGISTERED (err u107))
(define-constant ERR-REWARD-LIMIT-EXCEEDED (err u108))

;; Token metadata
(define-constant TOKEN-NAME "Wellness Token")
(define-constant TOKEN-SYMBOL "WELL")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI u"https://wellcoin.io/token-metadata.json")

;; Token economics
(define-constant INITIAL-SUPPLY u1000000000000) ;; 1M tokens with 6 decimals
(define-constant MAX-DAILY-REWARD u50000000) ;; 50 WELL max daily reward per user
(define-constant ADMIN-MINT-LIMIT u100000000000) ;; 100K WELL admin mint limit per transaction

;; =========================
;; Data Variables
;; =========================

(define-data-var token-total-supply uint u0)
(define-data-var contract-paused bool false)

;; =========================
;; Data Maps
;; =========================

;; SIP-010 standard balance tracking
(define-map token-balances principal uint)

;; Wellness-specific user data
(define-map user-wellness-data 
  principal
  {
    total-earned: uint,
    last-reward-block: uint,
    daily-reward-claimed: uint,
    wellness-level: uint,
    is-registered: bool
  }
)

;; Admin privileges for reward distribution
(define-map admin-privileges principal bool)

;; Daily reward tracking by block height
(define-map daily-rewards {user: principal, block-height: uint} uint)

;; =========================
;; Private Functions
;; =========================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-admin (user principal))
  (default-to false (map-get? admin-privileges user))
)

(define-private (get-balance-internal (account principal))
  (default-to u0 (map-get? token-balances account))
)

(define-private (set-balance (account principal) (amount uint))
  (map-set token-balances account amount)
)

(define-private (get-user-wellness-data (user principal))
  (default-to 
    {total-earned: u0, last-reward-block: u0, daily-reward-claimed: u0, wellness-level: u1, is-registered: false}
    (map-get? user-wellness-data user)
  )
)

(define-private (is-same-day (block1 uint) (block2 uint))
  ;; Assuming ~144 blocks per day (10 min blocks)
  (< (- block2 block1) u144)
)

(define-private (calculate-wellness-bonus (level uint) (base-amount uint))
  (if (> level u1)
    (+ base-amount (/ (* base-amount (- level u1)) u10))
    base-amount
  )
)

;; =========================
;; SIP-010 Functions
;; =========================

;; Transfer function - core SIP-010 requirement
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (var-get contract-paused)) (err u109))
    (asserts! (is-eq from tx-sender) ERR-NOT-TOKEN-OWNER)
    (asserts! (not (is-eq from to)) ERR-INVALID-RECIPIENT)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let ((from-balance (get-balance-internal from)))
      (asserts! (>= from-balance amount) ERR-INSUFFICIENT-BALANCE)
      
      (set-balance from (- from-balance amount))
      (set-balance to (+ (get-balance-internal to) amount))
      
      (print {action: "transfer", from: from, to: to, amount: amount, memo: memo})
      (ok true)
    )
  )
)

;; Get token name
(define-read-only (get-name)
  (ok TOKEN-NAME)
)

;; Get token symbol
(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

;; Get token decimals
(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

;; Get balance of account
(define-read-only (get-balance (account principal))
  (ok (get-balance-internal account))
)

;; Get total supply
(define-read-only (get-total-supply)
  (ok (var-get token-total-supply))
)

;; Get token URI
(define-read-only (get-token-uri)
  (ok (some TOKEN-URI))
)

;; =========================
;; Wellness-Specific Functions
;; =========================

;; Register a new user for wellness rewards
(define-public (register-user)
  (let ((user-data (get-user-wellness-data tx-sender)))
    (asserts! (not (get is-registered user-data)) ERR-ALREADY-REGISTERED)
    
    (map-set user-wellness-data tx-sender 
      (merge user-data {is-registered: true})
    )
    
    (print {action: "user-registered", user: tx-sender})
    (ok true)
  )
)

;; Mint wellness rewards - can only be called by admin or contract owner
(define-public (mint-wellness-reward (recipient principal) (amount uint))
  (begin
    (asserts! (not (var-get contract-paused)) (err u109))
    (asserts! (or (is-contract-owner) (is-admin tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let 
      (
        (user-data (get-user-wellness-data recipient))
        (current-block stacks-block-height)
        (daily-claimed (if (is-same-day (get last-reward-block user-data) current-block)
                        (get daily-reward-claimed user-data)
                        u0))
      )
      
      (asserts! (get is-registered user-data) ERR-NOT-REGISTERED)
      (asserts! (<= (+ daily-claimed amount) MAX-DAILY-REWARD) ERR-REWARD-LIMIT-EXCEEDED)
      
      (let ((bonus-amount (calculate-wellness-bonus (get wellness-level user-data) amount)))
        ;; Update user wellness data
        (map-set user-wellness-data recipient 
          {
            total-earned: (+ (get total-earned user-data) bonus-amount),
            last-reward-block: current-block,
            daily-reward-claimed: (+ daily-claimed amount),
            wellness-level: (get wellness-level user-data),
            is-registered: true
          }
        )
        
        ;; Mint tokens
        (set-balance recipient (+ (get-balance-internal recipient) bonus-amount))
        (var-set token-total-supply (+ (var-get token-total-supply) bonus-amount))
        
        (print {action: "wellness-reward-minted", recipient: recipient, amount: bonus-amount})
        (ok bonus-amount)
      )
    )
  )
)

;; Level up user's wellness level (increases bonus rewards)
(define-public (level-up-user (user principal))
  (begin
    (asserts! (or (is-contract-owner) (is-admin tx-sender)) ERR-UNAUTHORIZED)
    
    (let ((user-data (get-user-wellness-data user)))
      (asserts! (get is-registered user-data) ERR-NOT-REGISTERED)
      
      (map-set user-wellness-data user 
        (merge user-data {wellness-level: (+ (get wellness-level user-data) u1)})
      )
      
      (print {action: "level-up", user: user, new-level: (+ (get wellness-level user-data) u1)})
      (ok true)
    )
  )
)

;; Get user's wellness statistics
(define-read-only (get-wellness-stats (user principal))
  (ok (get-user-wellness-data user))
)

;; Get user's wellness balance (alias for get-balance)
(define-read-only (get-wellness-balance (user principal))
  (ok (get-balance-internal user))
)

;; =========================
;; Admin Functions
;; =========================

;; Add admin privileges
(define-public (add-admin (admin principal))
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (map-set admin-privileges admin true)
    (print {action: "admin-added", admin: admin})
    (ok true)
  )
)

;; Remove admin privileges
(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (map-delete admin-privileges admin)
    (print {action: "admin-removed", admin: admin})
    (ok true)
  )
)

;; Emergency pause/unpause contract
(define-public (toggle-pause)
  (begin
    (asserts! (is-contract-owner) ERR-OWNER-ONLY)
    (var-set contract-paused (not (var-get contract-paused)))
    (print {action: "contract-paused", paused: (var-get contract-paused)})
    (ok (var-get contract-paused))
  )
)

;; Burn tokens (reduce total supply)
(define-public (burn-tokens (amount uint))
  (begin
    (asserts! (not (var-get contract-paused)) (err u109))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (let ((user-balance (get-balance-internal tx-sender)))
      (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
      
      (set-balance tx-sender (- user-balance amount))
      (var-set token-total-supply (- (var-get token-total-supply) amount))
      
      (print {action: "tokens-burned", user: tx-sender, amount: amount})
      (ok true)
    )
  )
)

;; =========================
;; Initialization
;; =========================

;; Initialize contract with owner balance
(map-set token-balances CONTRACT-OWNER INITIAL-SUPPLY)
(var-set token-total-supply INITIAL-SUPPLY)

