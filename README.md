# aptos-escrow
This a module where users can swap their tokens where one person deposits the token in the escrow and when the other person transfer successfully, the tokens in the escrow get transferred to the other user.

Consider there are two people having Token A and Token B. They want to swap their token without a middlemen. They can do this using an escrow where tokens of
one person would be stored and get transfered to other person when they successfully do the transfer.

Consider Alice (with token A) and Bob (with token B)
- Intialize: Alice Transfers token A to the escrow account 
- Cancel: This is called when Bob fails to transfer the tokens or alice changes his mind of swapping the tokens. The tokens in the escrow account would be
transfered back to alice, thus canceling the exchange.
- Exchange: Bob transfers token B to the Alice and once this is done, the token A in escrow gets transfered to Bob. Thus completing the exchange.
