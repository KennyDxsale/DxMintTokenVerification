# DxMint Token Verification

The following document will share details on how to verify code for your generated token

### BSCScan, EtherScan or Similar
1. Start by first navigating to the verification section of BSCScan (https://bscscan.com/verifyContract) (Or for your chain)
2. Enter your DxMint generated token address 
3. For Compiler Type select "Solidity (Single File)"
4. For Compiler Version select "v0.8.7+commit.e28d00a7"
5. For Open Source License Type select "3) MIT License (MIT)"
6. Click continue
7. Now in the optimization field on the right select "Yes"
8. In the section that says enter solidity contract code below, copy paste the contract from correct folder in this github repository
9. At the very bottom of the page Verify the Captcha and click the Verify and Publish button
10. BSCScan will print an error saying "ByteCode (what we are looking for):"
    - Scroll all the way to the right of this section you will see a lot of 00000000000000's followed by a few numbers
    - Scroll to the left until the 0000000000000's stop 
    - You will see the following code {ipfs}64736f6c634300060c0033 at the end just before the long 00000000000000's start
    - Copy everything after the 0033 line (including the 00000's) 
    - [Sample copy: 000000000000000000000000f476cc43eeee4ad1d9f974ce1efffcafaf2a5e6a00000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000e8d9f193e6574c89800000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000003200000000000000000000000000000000000000000000000000000000000000074e45504a554e450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034e50450000000000000000000000000000000000000000000000000000000000]
11. Scroll down and click the start over button
12. In the section that says "Constructor Arguments ABI-Encoded" copy paste the variables copied from step 10 above
13. Verify the Captcha and click the Verify and Publish button.
14. Your code should now be verified.

** Important Note Core Chain: 
For Core chain token verification, follow upto step 9 and the contract will be verified. 
This includes for DxDividend Token as well.

#### DxDividend Token Verification
1. Make sure the IterableMapping library is verified first. Check if the contract address for IterableMapping is verified on the chain-specific blockexplorer. If not, verify using the steps mentioned above. Copy the contract code from the IterableMapping.txt file where required, select the optimization field to "Yes" like before. There will be no Bytecode error as there are no contract arguements to take care of.
2. To verify the token, same exact steps required for other token verification except for an additional step. In the Contract Library Address section, before you verify and publish, add the Library_1 Name "IterableMapping" and its address that was deployed with the specific type of dividend token deployer (Custom vs Native).
3. Make sure the runs value is correct under the Misc Settings/Runs (Optimizer) if optmizer was enabled for value different to 200.


Note:
For DxStandard, DxBurn and DxFee tokens:
    Compiler Version: v0.8.7
    Optimization -> yes
    Runs -> 200

For DxDividend tokens:
    Compiler Version: v0.8.14
    Optimization -> yes
    Runs -> 5
