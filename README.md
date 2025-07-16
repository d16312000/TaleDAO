# 📚 TaleDAO - Story Co-Creation DAO

> A decentralized autonomous organization where writers collaborate to create stories through democratic voting! ✍️🗳️

## 🌟 Overview

TaleDAO is a blockchain-based platform that enables collaborative storytelling through decentralized governance. Writers can create stories, propose new chapters, and vote on which chapters should be added to continue the narrative. The community decides the direction of each story through token-based voting.

## ✨ Features

- 📖 **Story Creation**: Anyone can start a new collaborative story
- 💡 **Chapter Proposals**: Submit your ideas for the next chapter
- 🗳️ **Democratic Voting**: Token holders vote on which chapters get added
- 🪙 **Token Economy**: Earn TALE tokens for participation and successful contributions
- 👥 **Community Driven**: Stories evolve based on collective decisions
- 📊 **Transparent Governance**: All votes and decisions are recorded on-chain

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

```bash
git clone <your-repo>
cd taledao
clarinet check
```

## 🎮 How to Use

### 1. Create a Story 📝
```clarity
(contract-call? .TaleDAO create-story "My Amazing Adventure")
```
- Creates a new story with the given title
- Rewards creator with 100 TALE tokens
- Returns a unique story ID

### 2. Propose a Chapter 💭
```clarity
(contract-call? .TaleDAO propose-chapter u1 "The hero discovered a mysterious door...")
```
- Costs 10 TALE tokens to submit
- Creates a proposal that others can vote on
- Voting period lasts 144 blocks (~24 hours)

### 3. Vote on Proposals 🗳️
```clarity
(contract-call? .TaleDAO vote-on-proposal u1 true)
```
- Costs 5 TALE tokens to vote
- `true` = vote for, `false` = vote against
- Each user can only vote once per proposal

### 4. Execute Winning Proposals ⚡
```clarity
(contract-call? .TaleDAO execute-proposal u1)
```
- Can only be executed after voting period ends
- Requires more "for" votes than "against" votes
- Adds the chapter to the story and rewards the author with 50 TALE tokens

## 🪙 Token Economy

- **Story Creation**: +100 TALE tokens
- **Chapter Proposal**: -10 TALE tokens
- **Voting**: -5 TALE tokens
- **Successful Chapter**: +50 TALE tokens

## 📋 Read-Only Functions

- `get-story(story-id)` - Get story details
- `get-chapter(story-id, chapter-id)` - Get specific chapter
- `get-proposal(proposal-id)` - Get proposal details
- `get-balance(user)` - Get user's token balance
- `get-story-count()` - Total number of stories
- `get-token-supply()` - Total TALE tokens in circulation

## 🔧 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🎯 Roadmap

- [ ] Chapter editing and revision system
- [ ] Story categories and tags
- [ ] Advanced voting mechanisms
- [ ] NFT integration for completed stories
- [ ] Mobile-friendly interface

---

*Happy storytelling! 📚✨*


