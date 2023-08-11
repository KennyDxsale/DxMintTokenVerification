/*
// Official DxFee Token
// To Mint your own token visit https://dx.app
// DxMint verified tokens are unruggable through code
// To view the audit certificate for this token search it in https://dx.app/dxmint
// Please ensure one wallet doesn't hold too much supply of tokens!
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import '../libraries/SafeMath.sol';
import '../libraries/Address.sol';
import '../libraries/Ownable.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IBabyFactory.sol';
import '../interfaces/IUniswapV2Router02.sol';

contract DxFeeToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    address private dead = 0x000000000000000000000000000000000000dEaD;
    uint256 public maxLiqFee = 10;
    uint256 public maxTaxFee = 10; 
    uint256 public maxDevFee = 10;
    uint256 public minMxTxPercentage = 50;
    uint256 public maxSellTaxFee = 20;
    uint256 public prevLiqFee;
    uint256 public prevTaxFee;
    uint256 public prevDevFee;
    uint256 public prevSellFee;
    
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;
    mapping (address => bool) private _isdevWallet;
    
    address[] private _excluded;
    address public _devWalletAddress;     // team wallet here
    address public router;
    address public basePair;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    bool public mintedByDxsale = true;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    uint256 public _taxFee;
    uint256 private _previousTaxFee;
    
    uint256 public _liquidityFee;
    uint256 private _previousLiquidityFee;
    
    uint256 public _devFee;
    uint256 private _previousDevFee = _devFee;

    uint256 public _sellTaxFee;
    uint256 private _previousSellFee;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool public inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;
    
    uint256 public _maxTxAmount;
    uint256 public numTokensSellToAddToLiquidity;
    
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor (address tokenOwner,string memory name_, string memory symbol_,uint8 decimal_, uint256 amountOfTokenWei,uint8[4] memory setFees, uint256[5] memory maxFees, address devWalletAddress_, address _router, address _basePair) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimal_;
        _tTotal = amountOfTokenWei;
        _rTotal = (MAX - (MAX % _tTotal));
        router = _router;
        basePair = _basePair;    
        _rOwned[tokenOwner] = _rTotal;
        
        maxTaxFee = maxFees[0];        
        maxLiqFee = maxFees[1];
        maxDevFee = maxFees[2];
        minMxTxPercentage = maxFees[3];
        maxSellTaxFee = maxFees[4]; 
        _taxFee = setFees[0];
        _previousTaxFee = _taxFee;     
        _liquidityFee = setFees[1];
        _previousLiquidityFee = _liquidityFee;
        _devFee = setFees[2];
        _previousDevFee = _devFee;
        _sellTaxFee = setFees[3];  
        _previousSellFee = _sellTaxFee;      
        _devWalletAddress = devWalletAddress_;

        _maxTxAmount = amountOfTokenWei;
        numTokensSellToAddToLiquidity = amountOfTokenWei.mul(1).div(1000);
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
         // Create a uniswap pair for this new token
        uniswapV2Pair = UniSwapFactory(_uniswapV2Router.factory())
            .createPair(address(this), basePair);

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_devWalletAddress] = true;
    
        //set wallet provided to true
        _isdevWallet[_devWalletAddress] = true;
        
        emit Transfer(address(0), tokenOwner, _tTotal);
    }

    function getWrapAddr() public view returns (address){

        return basePair;

    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }
    
    function excludeFromFee(address account) public onlyOwner {
        require(!_isExcludedFromFee[account], "Account is already excluded");
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        require(_isExcludedFromFee[account], "Account is already included");
        _isExcludedFromFee[account] = false;
    }
    
    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
         require(taxFee >= 0 && taxFee <=maxTaxFee,"taxFee out of range");
        _taxFee = taxFee;
        _previousTaxFee = _taxFee;
    }
    
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
         require(liquidityFee >= 0 && liquidityFee <=maxLiqFee,"liquidityFee out of range");
        _liquidityFee = liquidityFee;
        _previousLiquidityFee = _liquidityFee;
    }
    
    function setDevFeePercent(uint256 devFee) external onlyOwner() {
        require(devFee >= 0 && devFee <=maxDevFee,"teamFee out of range");
        _devFee = devFee;
        _previousDevFee = _devFee;
    }      

    function setSellTaxFeePercent(uint256 sellTaxFee) external onlyOwner() {
         require(sellTaxFee >= 0 && sellTaxFee <=maxSellTaxFee,"taxFee out of range");
        _sellTaxFee = sellTaxFee;
        _previousSellFee = _sellTaxFee;
    }
   
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        require(maxTxPercent >= minMxTxPercentage && maxTxPercent <=100,"maxTxPercent out of range");
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
    }
        
    function setDevWalletAddress(address _addr) internal virtual {
        if (!_isExcludedFromFee[_addr]) {
            excludeFromFee(_addr);
        }
        _isdevWallet[_addr] = true;
        _devWalletAddress = _addr;
    }

    function replaceDevWalletAddress(address _addr, address _newAddr) public onlyOwner {
        require(_isdevWallet[_addr], "Wallet address not set previously");
        require(!_isdevWallet[_newAddr], "Wallet address already set");
        if (_isExcludedFromFee[_addr]) {
            includeInFee(_addr);
        }
        _isdevWallet[_addr] = false;
        setDevWalletAddress(_newAddr);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, tDev, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tDev);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tDev = calculateDevFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity).sub(tDev);
        return (tTransferAmount, tFee, tLiquidity, tDev);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rDev = tDev.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity).sub(rDev);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
    
    function _takeDev(uint256 tDev) private {
        uint256 currentRate = _getRate();
        uint256 rDev = tDev.mul(currentRate);
        _rOwned[_devWalletAddress] = _rOwned[_devWalletAddress].add(rDev);
        if(_isExcluded[_devWalletAddress])
            _tOwned[_devWalletAddress] = _tOwned[_devWalletAddress].add(tDev);
    }    
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
            return _amount.mul(_taxFee).div(
                10**2
            );
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10**2
        );
    }
    
    function calculateDevFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_devFee).div(
            10**2
        );
    }    
    
    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0 && _devFee == 0) return;
        
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousDevFee = _devFee;
        _previousSellFee = _sellTaxFee;
        
        _taxFee = 0;
        _liquidityFee = 0;
        _devFee = 0;
        _sellTaxFee = 0;
    }
    
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _devFee = _previousDevFee;
        _sellTaxFee = _previousSellFee;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(!_isExcludedFromFee[from]){
            require(amount > 0, "Transfer amount must be greater than zero");
        }

        //Special case when sell is uniswapV2Pair
        if (to == uniswapV2Pair){
            _taxFee = _sellTaxFee;
        }

        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);

        //reset tax fees
        restoreAllFee();
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> WHT
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = getWrapAddr();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        try uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        ) {}

        catch(bytes memory) {

            try uniswapV2Router.swapExactTokensForBNBSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of ETH
                path,
                address(this),
                block.timestamp
            ) {}
            catch(bytes memory) {
                try uniswapV2Router.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
                    tokenAmount,
                    0, // accept any amount of ETH
                    path,
                    address(this),
                    block.timestamp
                ){}

                catch(bytes memory) {
                    try uniswapV2Router.swapExactTokensForHTSupportingFeeOnTransferTokens(
                        tokenAmount,
                        0, // accept any amount of ETH
                        path,
                        address(this),
                        block.timestamp
                    ){}
                    catch(bytes memory) {

                        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                            tokenAmount,
                            0, // accept any amount of ETH
                            path,
                            address(this),
                            block.timestamp
                        );


                    }


                }

            }

        }
    }

    function addLiquidity(uint256 tokenAmount, uint256 ETHAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity

        try uniswapV2Router.addLiquidityETH{value : ETHAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            dead,
            block.timestamp
        ) {

        }

        catch (bytes memory) {
            try uniswapV2Router.addLiquidityBNB{value : ETHAmount}(
                address(this),
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                dead,
                block.timestamp
            ) {

            }
            catch (bytes memory) {
                try uniswapV2Router.addLiquidityAVAX{value : ETHAmount}(
                    address(this),
                    tokenAmount,
                    0, // slippage is unavoidable
                    0, // slippage is unavoidable
                    dead,
                    block.timestamp
                ) {

                }
                catch (bytes memory) {
                    try uniswapV2Router.addLiquidityHT{value : ETHAmount}(
                        address(this),
                        tokenAmount,
                        0, // slippage is unavoidable
                        0, // slippage is unavoidable
                        dead,
                        block.timestamp
                    ) {

                    }
                    catch (bytes memory) {

                        uniswapV2Router.addLiquidityETH{value : ETHAmount}(
                            address(this),
                            tokenAmount,
                            0, // slippage is unavoidable
                            0, // slippage is unavoidable
                            dead,
                            block.timestamp
                        );
                    }

                }

            }
        }

    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        } 
        
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeDev(tDev);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeLiquidity(tLiquidity);
        _takeDev(tDev);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeLiquidity(tLiquidity);
        _takeDev(tDev);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tDev) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeLiquidity(tLiquidity);
        _takeDev(tDev);        
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function disableFees() public onlyOwner {
        prevLiqFee = _liquidityFee;
        prevTaxFee = _taxFee;
        prevDevFee = _devFee;
        prevSellFee = _sellTaxFee;
        _maxTxAmount = _tTotal;
        _liquidityFee = 0;
        _taxFee = 0;
        _devFee = 0;
        _sellTaxFee = 0;
        swapAndLiquifyEnabled = false;
        
    }
    
    function enableFees() public onlyOwner {
        
        _maxTxAmount = _tTotal;
        _liquidityFee = prevLiqFee;
        _taxFee = prevTaxFee;
        _devFee = prevDevFee;
        _sellTaxFee = prevSellFee;
        swapAndLiquifyEnabled = true;
        
    }

}
