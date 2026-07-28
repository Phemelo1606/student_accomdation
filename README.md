# Smart Student Accommodation — README

Quick reference for setting up and running the app (Firebase + IPFS + Blockchain).

## Overview
This Flutter app uses:
- Firebase (Auth, Firestore, Storage, FCM)
- IPFS (store lease PDFs)
- Blockchain (smart contract `LeaseAgreement.sol` for lease records)
- PDF generation + IPFS upload + contract interactions from chat UI

Files of interest
- `lib/main.dart` — app bootstrap (Firebase init + routes)
- `lib/core/routes.dart` — navigation
- `lib/services/*` — blockchain_service, ipfs_service, pdf_service, chatService, applicationService
- `lib/pages/chatScreen.dart` — lease creation, IPFS upload and blockchain flow
- `lib/features/lease/LeaseAgreement.sol` — Solidity smart contract

**Current status:** `lib/services/blockchain_service.dart` currently persists lease
records to Firestore and generates a mock transaction hash — it does not yet call
`LeaseAgreement.sol` on-chain. The contract compiles and is ready to deploy, but the
Dart-to-chain wiring (via `web3dart`, already a dependency) is not implemented yet.

---

## Prerequisites
- Flutter (stable) installed and on PATH
- Dart SDK (comes with Flutter)
- Node.js & npm (for Hardhat/Truffle deployment)
- Local blockchain (Ganache) or a testnet provider (Alchemy/Infura)
- IPFS node or IPFS pinning service account
- Firebase project (Console) access
- PowerShell (Windows) or terminal in VS Code

---

## 1) Firebase setup
1. Create a Firebase project in Firebase Console.
2. Enable:
   - Authentication (Email/Password)
   - Firestore (in production set rules)
   - Storage (for optional uploads)
   - Cloud Messaging (optional)
3. Register your app(s) and obtain config. The repo already contains `firebase_options.dart`. If regenerating:
   - Install FlutterFire CLI:
     ```
     dart pub global activate flutterfire_cli
     ```
   - Run from project root:
     ```
     flutterfire configure
     ```
   - This generates/updates `lib/firebase_options.dart`.

4. Firestore collections used by app (examples)
   - `chats/{chatId}/messages/{messageId}`: senderId, text/type, timestamp, leaseData, ipfsHash, transactionHash, leaseStatus
   - `chats/{chatId}`: participants[], lastMessageTimestamp, studentName, landlordName
   - `Accommodations/{accId}/Rooms/{roomId}`: RoomNumber, MonthlyRent, AvailabilityStatus, Images...
   - `StudentRooms/{studentId}`: RoomID, AccommodationID, LeaseDocumentId, IsActive
   - Add any additional collections used by services (applications, maintenance, users)

5. Recommended Firestore rules (development)
   - Start permissive for dev then harden before production.
   - Use Firebase Auth UID checks to restrict writes to own documents.

---

## 2) IPFS setup
Options:
- Local IPFS node: install go-ipfs (https://docs.ipfs.io/install/)
  - Start daemon:
    ```
    ipfs init
    ipfs daemon
    ```
- Hosted pinning / storage (recommended for production):
  - web3.storage, Infura IPFS, Pinata — create API key.

Configure env variables (see section Env). Example variables:
- IPFS_ENDPOINT (RPC/http endpoint)
- IPFS_API_KEY or WEB3_STORAGE_API_KEY

The app uses `lib/services/ipfs_service.dart` — ensure the service matches chosen provider API.

---

## 3) Blockchain setup (development)
1. Choose environment:
   - Local: Ganache (RPC at http://127.0.0.1:7545)
   - Testnet: Goerli/Scroll via Alchemy/Infura
2. Compile & deploy `lease/LeaseAgreement.sol` with Hardhat or Truffle:
   - Hardhat quick steps:
     ```
     npm init -y
     npm install --save-dev hardhat @nomiclabs/hardhat-ethers ethers
     npx hardhat
     # create deploy script to deploy LeaseAgreement.sol
     npx hardhat run scripts/deploy.js --network <network>
     ```
3. Note deployed contract address and ABI. Update config used by `lib/services/blockchain_service.dart` or `lib/config/app_config.dart`.

Env variables for blockchain:
- RPC_URL (e.g., http://127.0.0.1:7545 or https://eth-goerli.alchemyapi.io/v2/...)
- CONTRACT_ADDRESS (deployed LeaseAgreement address)
- LANDLORD_PRIVATE_KEY
- STUDENT_PRIVATE_KEY (for test signing flows)
- CHAIN_ID (optional for tx building)

Warning: Never commit real private keys. Use test keys in dev.

---

## 4) Environment variables (secrets)
Secrets (Pinata API key/secret, and any future RPC URLs / private keys) are **never**
hardcoded in `lib/config/app_config.dart` — they're passed at build/run time via
`--dart-define-from-file` so they never end up in source control.

1. Copy the example file:
   ```
   cp env.json.example env.json
   ```
2. Fill in real values in `env.json` (this file is gitignored — it will not be committed):
   ```json
   {
     "PINATA_API_KEY": "your-pinata-api-key",
     "PINATA_SECRET_KEY": "your-pinata-secret-key",
     "USE_MOCK_SERVICES": false
   }
   ```
3. Run/build with the env file:
   ```
   flutter run --dart-define-from-file=env.json
   flutter build apk --dart-define-from-file=env.json
   ```

If no Pinata key is supplied, `ipfs_service.dart` automatically falls back to a mock
IPFS implementation, so the app still runs without any secrets configured.

**Security note:** this project previously had a live Pinata API key and secret
hardcoded directly in `app_config.dart`. That key has been moved out of source as
part of this change — if this repository has ever been shared, pushed anywhere, or
zipped/emailed, rotate that key in the Pinata dashboard as a precaution.

---

## 5) Testing

```
flutter test
```

Coverage so far:
- `test/core/search_filters_test.dart` — pure logic for the `SearchFilters` model.
- `test/services/room_search_service_test.dart` — room filtering/search-option logic
  in `RoomSearchService` (no Firestore round trip needed).
- `test/services/application_service_test.dart`,
  `test/services/favorites_service_test.dart`,
  `test/services/blockchain_service_test.dart` — Firestore-backed services, tested
  against an in-memory `FakeFirebaseFirestore` (via the `fake_cloud_firestore` and
  `firebase_auth_mocks` dev dependencies) rather than a real Firebase project.

`ApplicationService`, `FavoritesService`, `BlockchainService`, and `RoomSearchService`
all take an optional constructor parameter (e.g. `BlockchainService({FirebaseFirestore?
firestore})`) so tests can inject a fake instance instead of hitting
`FirebaseFirestore.instance` — existing call sites that construct these with no
arguments are unaffected.

**Note:** `ApplicationService.acceptApplication()` is fully tested but is not
currently called from anywhere in the UI — room assignment on the landlord side
currently happens through the chat/lease-signing flow in `chatScreen.dart` instead.
It looks like an earlier, now-superseded "accept application" flow; worth deciding
whether to wire it up or remove it.

CI runs `flutter analyze` and `flutter test` on every push/PR to `main` — see
`.github/workflows/flutter_ci.yml`.
