# Wellcoin - Wellness Reward Token System

A blockchain-based wellness incentive platform built on the Stacks blockchain using Clarity smart contracts. Wellcoin rewards users with tokens for verified wellness activities, promoting healthy lifestyle habits through gamification and financial incentives.

## 🌟 Overview

Wellcoin is a decentralized wellness reward system that allows users to:
- Earn WELL tokens for completing verified wellness activities
- Track their wellness journey on-chain
- Redeem tokens for wellness-related rewards
- Participate in a community-driven health ecosystem

## 🏗️ Architecture

The system consists of two main smart contracts:

### 1. Wellness Token Contract (`wellness-token.clar`)
- **SIP-010 Compliant**: Full fungible token implementation
- **Token Management**: Minting, burning, and transfer capabilities
- **Reward Distribution**: Automated token rewards for verified activities
- **Access Control**: Admin functions for system management

### 2. Wellness Tracker Contract (`wellness-tracker.clar`)
- **Activity Logging**: Records various wellness activities
- **Verification System**: Ensures activity authenticity
- **Progress Tracking**: Monitors user wellness streaks and achievements
- **Reward Calculation**: Determines token rewards based on activity type and frequency

## 🎯 Key Features

### Token Economics
- **Token Symbol**: WELL
- **Decimal Places**: 6
- **Initial Supply**: 1,000,000 WELL tokens
- **Reward Mechanism**: Dynamic rewards based on activity type and user consistency

### Supported Activities
- **Exercise**: Cardio, strength training, yoga, sports
- **Nutrition**: Healthy meal logging, hydration tracking
- **Mental Health**: Meditation, sleep tracking, stress management
- **Preventive Care**: Health check-ups, screenings

### Verification Methods
- **Self-Reporting**: Basic activity logging with streak incentives
- **Device Integration**: Future support for fitness tracker validation
- **Community Verification**: Peer validation for certain activities

## 📋 Smart Contract Functions

### Wellness Token Contract
```clarity
;; Core SIP-010 Functions
(transfer (amount uint) (from principal) (to principal))
(get-balance (who principal))
(get-total-supply)

;; Wellness-Specific Functions
(mint-wellness-reward (recipient principal) (amount uint))
(get-wellness-balance (user principal))
(burn-tokens (amount uint))
```

### Wellness Tracker Contract
```clarity
;; Activity Management
(log-activity (activity-type (string-ascii 50)) (duration uint) (intensity uint))
(get-user-activities (user principal))
(get-activity-streak (user principal))

;; Verification & Rewards
(verify-activity (activity-id uint))
(calculate-reward (activity-type (string-ascii 50)) (duration uint))
(claim-activity-reward (activity-id uint))
```

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) for testing framework
- Stacks wallet for mainnet interaction

### Installation
```bash
# Clone the repository
git clone https://github.com/sarahwaba70-cyber/wellcoin.git
cd wellcoin

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test
```

### Local Development
```bash
# Start local blockchain
clarinet integrate

# Deploy contracts locally
clarinet deploy --devnet
```

## 🧪 Testing

The project includes comprehensive tests for both contracts:

```bash
# Run all tests
npm test

# Run specific contract tests
npx vitest run tests/wellness-token.test.ts
npx vitest run tests/wellness-tracker.test.ts
```

## 📊 Token Reward Structure

| Activity Type | Base Reward (WELL) | Bonus Conditions |
|---------------|-------------------|------------------|
| Cardio Exercise | 10 | +5 for 30+ min sessions |
| Strength Training | 15 | +10 for progressive overload |
| Yoga/Meditation | 8 | +3 for daily practice |
| Healthy Meal | 5 | +2 for balanced macros |
| Sleep (8+ hours) | 12 | +8 for consistent bedtime |
| Health Checkup | 50 | Annual bonus available |

## 🛡️ Security Features

- **Input Validation**: All user inputs are thoroughly validated
- **Access Control**: Admin functions protected with proper authorization
- **Overflow Protection**: Safe arithmetic operations throughout
- **Reentrancy Guards**: Protection against malicious contract interactions

## 🎮 User Experience

### Activity Logging Flow
1. User logs wellness activity with details (type, duration, intensity)
2. System validates activity parameters
3. Activity is recorded with timestamp and unique ID
4. Reward calculation is performed based on activity metrics
5. WELL tokens are minted and transferred to user's wallet

### Verification Process
1. Activities are initially marked as "pending"
2. Verification occurs through various methods:
   - Automatic verification for self-reported activities after 24 hours
   - Device data integration (future feature)
   - Community validation for high-value activities
3. Verified activities unlock token rewards

## 🌍 Future Roadmap

### Phase 2: Enhanced Verification
- Integration with popular fitness trackers (Fitbit, Apple Health, Garmin)
- Photo verification for certain activities
- GPS verification for outdoor activities

### Phase 3: Social Features
- Wellness challenges and competitions
- Team-based wellness goals
- Community leaderboards and achievements

### Phase 4: Marketplace Integration
- Partner wellness brands for token redemption
- NFT achievements and badges
- Staking mechanisms for long-term holders

## 🤝 Contributing

We welcome contributions to the Wellcoin ecosystem! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Make your changes and add tests
4. Run `clarinet check` and `npm test` to ensure everything passes
5. Commit your changes (`git commit -m 'Add new feature'`)
6. Push to your branch (`git push origin feature/new-feature`)
7. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet/)

## ⚠️ Disclaimer

Wellcoin is an experimental project designed to incentivize wellness activities. It is not intended as financial or medical advice. Users should consult healthcare professionals for medical guidance and understand the risks associated with cryptocurrency and blockchain technology.

---

**Built with ❤️ for a healthier, more rewarded world**
