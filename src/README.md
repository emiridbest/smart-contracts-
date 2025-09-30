# src/

This folder contains Solidity contracts for the project.

Layout convention:
- `src/miniSafe/` - core MiniSafe contracts
- `src/*.sol` - standalone contracts (faucets, utilities)

Notes:
- Keep contracts organized by feature and add a README for subfolders with larger codebases.
- Use `remappings.txt` to resolve imports from `lib/`.
