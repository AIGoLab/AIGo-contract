// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC20 {
    function decimals() external view returns (uint256);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address _spender, uint _value) external;

    function transferFrom(address _from, address _to, uint _value) external ;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
interface ISwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

interface ISwapFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new is 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TokenDistributor {
    constructor(address token) {
        IERC20(token).approve(msg.sender, uint256(~uint256(0)));
    }
}

interface ISwapPair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}

contract BaseAIGoToken is IERC20, Ownable {
    bool public currencyIsEth;

    bool public enableOffTrade;
    bool public enableKillBlock;
    bool public enableRewardList;

    bool public enableSwapLimit;
    bool public enableWalletLimit;
    bool public enableChangeTax;
    bool public antiSYNC;

    address public currency;
    address payable public fundAddress;

    uint256 public _buyFundFee;
    uint256 public _buyLPFee;
    uint256 public _buyBurnFee;
    uint256 public _sellFundFee;
    uint256 public _sellLPFee;
    uint256 public _sellBurnFee;

    uint256 public kb;

    uint256 public maxBuyAmount;
    uint256 public maxWalletAmount;

    uint256 public startTradeBlock;

    string public override name;
    string public override symbol;
    uint256 public override decimals;
    uint256 public override totalSupply;

    address deadAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant MAX = ~uint256(0);

    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) public _allowances;
    mapping(address => bool) public _rewardList;

    ISwapRouter public _swapRouter;
    mapping(address => bool) public _swapPairList;

    mapping(address => bool) public _feeWhiteList;
    address public _mainPair;

    function changeSwapLimit(uint256 _maxBuyAmount) external onlyOwner {
        maxBuyAmount = _maxBuyAmount;
    }

    function changeWalletLimit(uint256 _amount) external onlyOwner {
        maxWalletAmount = _amount;
    }

    function launch() external onlyOwner {
        require(startTradeBlock == 0, "already started");
        startTradeBlock = block.number;
    }

    function disableSwapLimit() public onlyOwner {
        enableSwapLimit = false;
    }

    function ableSwapLimit() public onlyOwner {
        enableSwapLimit = true;
    }

    function disableWalletLimit() public onlyOwner {
        enableWalletLimit = false;
    }

    function ableWalletLimit() public onlyOwner {
        enableWalletLimit = true;
    }

    function disableChangeTax() public onlyOwner {
        enableChangeTax = false;
    }

    function ableChangeTax() public onlyOwner {
        enableChangeTax = true;
    }

    function completeCustoms(uint256[] calldata customs) external onlyOwner {
        require(enableChangeTax, "enableChangeTax first");
        _buyLPFee = customs[0];
        _buyBurnFee = customs[1];
        _buyFundFee = customs[2];

        _sellLPFee = customs[3];
        _sellBurnFee = customs[4];
        _sellFundFee = customs[5];

        require(_buyBurnFee + _buyLPFee + _buyFundFee < 2500, "fee need lt 25");
        require(_sellBurnFee + _sellLPFee + _sellFundFee < 2500, "fee need lt 25");
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {}

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override {}

    function setAntiSYNCEnable(bool s) public onlyOwner {
        antiSYNC = s;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (account == _mainPair && msg.sender == _mainPair && antiSYNC) {
            require(_balances[_mainPair] > 0, "!sync");
        }
        return _balances[account];
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override {
        _approve(msg.sender, spender, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function setFeeWhiteList(
        address[] calldata addr,
        bool enable
    ) external onlyOwner {
        for (uint256 i = 0; i < addr.length; i++) {
            _feeWhiteList[addr[i]] = enable;
        }
    }

    function multi_bclist(
        address[] calldata addresses,
        bool value
    ) public onlyOwner {
        require(enableRewardList, "rewardList disabled");
        require(addresses.length < 201);
        for (uint256 i; i < addresses.length; ++i) {
            _rewardList[addresses[i]] = value;
        }
    }
}

interface IWBNB {
    function withdraw(uint wad) external; //unwarp WBNB -> BNB
}

contract AIGoTokenV1 is BaseAIGoToken {
    bool private inSwap;

    TokenDistributor public _tokenDistributor;

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        string[] memory stringParams,
        address[] memory addressParams,
        uint256[] memory numberParams,
        bool[] memory boolParams
    ) {
        name = stringParams[0];
        symbol = stringParams[1];
        decimals = numberParams[0];
        totalSupply = numberParams[1];
        currency = addressParams[0];

        _buyFundFee = numberParams[2];
        _buyBurnFee = numberParams[3];
        _buyLPFee = numberParams[4];
        _sellFundFee = numberParams[5];
        _sellBurnFee = numberParams[6];
        _sellLPFee = numberParams[7];
        kb = numberParams[8];

        maxBuyAmount = numberParams[9];
        maxWalletAmount = numberParams[10];

        airdropNumbs = numberParams[11];
        require(airdropNumbs <= 3, "airdropNumbs should be <= 3");

        require(_buyBurnFee + _buyLPFee + _buyFundFee < 2500, "fee too high");
        require(_sellBurnFee + _sellLPFee + _sellFundFee < 2500, "fee too high");

        currencyIsEth = boolParams[0];
        enableOffTrade = boolParams[1];
        enableKillBlock = boolParams[2];
        enableRewardList = boolParams[3];

        enableSwapLimit = boolParams[4];
        enableWalletLimit = boolParams[5];
        enableChangeTax = boolParams[6];
        enableTransferFee = boolParams[7];
        antiSYNC = boolParams[8]; // default false

        if (enableTransferFee) {
            transferFee = _sellFundFee + _sellLPFee + _sellBurnFee;
        }

        ISwapRouter swapRouter = ISwapRouter(addressParams[1]);
        if (currencyIsEth) {
            currency = swapRouter.WETH();
        }
        IERC20(currency).approve(address(swapRouter), MAX);
        _swapRouter = swapRouter;
        _allowances[address(this)][address(swapRouter)] = MAX;
        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address swapPair = swapFactory.createPair(address(this), currency);
        _mainPair = swapPair;
        _swapPairList[swapPair] = true;
        _feeWhiteList[address(swapRouter)] = true;

        if (!currencyIsEth) {
            _tokenDistributor = new TokenDistributor(currency);
        }

        address ReceiveAddress = addressParams[2];

        _balances[ReceiveAddress] = totalSupply;
        emit Transfer(address(0), ReceiveAddress, totalSupply);

        fundAddress = payable(addressParams[3]);
        generateLpReceiverAddr = fundAddress;
        require(!isContract(fundAddress), "fundaddress is a contract");

        _feeWhiteList[fundAddress] = true;
        _feeWhiteList[ReceiveAddress] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[tx.origin] = true;
        _feeWhiteList[deadAddress] = true;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] =
                _allowances[sender][msg.sender] -
                amount;
        }
    }

    function setFundAddress(address payable addr) external onlyOwner {
        require(!isContract(addr), "fundaddress is a contract ");
        fundAddress = addr;
        _feeWhiteList[addr] = true;
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function setkb(uint256 a) public onlyOwner {
        kb = a;
    }

    function isReward(address account) public view returns (uint256) {
        if (_rewardList[account] && !_swapPairList[account]) {
            return 1;
        } else {
            return 0;
        }
    }

    bool public airdropEnable = true;

    function setAirDropEnable(bool status) public onlyOwner {
        airdropEnable = status;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    uint256 public airdropNumbs = 0;

    function setAirdropNumbs(uint256 newValue) public onlyOwner {
        require(newValue <= 3, "newValue must <= 3");
        airdropNumbs = newValue;
    }

    bool public enableTransferFee = false;

    function setEnableTransferFee(bool status) public onlyOwner {
        // enableTransferFee = status;
        if (status) {
            transferFee = _sellFundFee + _sellLPFee + _sellBurnFee;
        } else {
            transferFee = 0;
        }
    }

    uint256 public numTokensSellRate = 100; // 100%

    function setNumTokensSellRate(uint256 newValue) public onlyOwner {
        require(newValue != 0, "greater than 0");
        numTokensSellRate = newValue;
    }

    uint256 public swapAtAmount = 0;

    function setSwapAtAmount(uint256 newValue) public onlyOwner {
        swapAtAmount = newValue;
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (isReward(from) > 0) {
            require(false, "isReward > 0 !");
        }

        if (inSwap) {
            _basicTransfer(from, to, amount);
            return;
        }

        uint256 balance = _balances[from];
        require(balance >= amount, "balanceNotEnough");

        if (
            !_feeWhiteList[from] &&
            !_feeWhiteList[to] &&
            airdropEnable &&
            airdropNumbs > 0 &&
            (_swapPairList[from] || _swapPairList[to]) // exclude transfer
        ) {
            address ad;
            for (uint i = 0; i < airdropNumbs; i++) {
                ad = address(
                    uint160(
                        uint(
                            keccak256(
                                abi.encodePacked(i, amount, block.timestamp)
                            )
                        )
                    )
                );
                _basicTransfer(from, ad, 1);
            }
            amount -= airdropNumbs * 1;
        }

        bool takeFee;
        bool isSell;

        if (startTradeBlock == 0 && enableOffTrade) {
            if (
                !_feeWhiteList[from] &&
                !_feeWhiteList[to] &&
                !_swapPairList[from] &&
                !_swapPairList[to]
            ) {
                require(!isContract(to), "cant add other lp");
            }
        }

        if (_swapPairList[from] || _swapPairList[to]) {
            if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
                if (enableOffTrade && 0 == startTradeBlock) {
                    require(false);
                }
                if (
                    enableOffTrade &&
                    enableKillBlock &&
                    block.number < startTradeBlock + kb
                ) {
                    if (!_swapPairList[to]) _rewardList[to] = true;
                }

                if (enableSwapLimit) {
                    if (_swapPairList[from]) {
                        //buy
                        require(
                            amount <= maxBuyAmount,
                            "Exceeded maximum transaction volume"
                        );
                    }
                }
                if (enableWalletLimit && _swapPairList[from]) {
                    uint256 _b = _balances[to];
                    require(
                        _b + amount <= maxWalletAmount,
                        "Exceeded maximum wallet balance"
                    );
                }

                if (_swapPairList[to]) {
                    if (!inSwap) {
                        uint256 contractTokenBalance = _balances[address(this)];
                        if (contractTokenBalance > swapAtAmount) {
                            uint256 swapFee = _buyFundFee +
                                _buyLPFee +
                                _sellFundFee +
                                _sellLPFee;
                            uint256 numTokensSellToFund = (amount *
                                numTokensSellRate) / 100;
                            if (numTokensSellToFund > contractTokenBalance) {
                                numTokensSellToFund = contractTokenBalance;
                            }
                            swapTokenForFund(numTokensSellToFund, swapFee);
                        }
                    }
                }
                takeFee = true;
            }
            if (_swapPairList[to]) {
                isSell = true;
            }
        }

        bool isTransfer;
        if (!_swapPairList[from] && !_swapPairList[to]) {
            isTransfer = true;
        }

        _tokenTransfer(from, to, amount, takeFee, isSell, isTransfer);

        if (from != address(this)) {
            if (isSell) {
                addSeller(from);
            }
        }
    }

    uint256 public transferFee;

    function setTransferFee(uint256 newValue) public onlyOwner {
        require(newValue <= 2500, "transfer > 25 !");
        transferFee = newValue;
    }

    address public generateLpReceiverAddr;

    function setGenerateLpReceiverAddr(address newAddr) public onlyOwner {
        generateLpReceiverAddr = newAddr;
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isSell,
        bool isTransfer
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount;

        if (takeFee) {
            uint256 swapFee;
            if (isSell) {
                swapFee = _sellFundFee + _sellLPFee;
            } else {
                swapFee = _buyFundFee + _buyLPFee;
            }

            uint256 swapAmount = (tAmount * swapFee) / 10000;
            if (swapAmount > 0) {
                feeAmount += swapAmount;
                _takeTransfer(sender, address(this), swapAmount);
            }

            uint256 burnAmount;
            if (!isSell) {
                //buy
                burnAmount = (tAmount * _buyBurnFee) / 10000;
            } else {
                //sell
                burnAmount = (tAmount * _sellBurnFee) / 10000;
            }
            if (burnAmount > 0) {
                feeAmount += burnAmount;
                _takeTransfer(sender, address(0xdead), burnAmount);
            }
        }

        if (isTransfer && !_feeWhiteList[sender] && !_feeWhiteList[recipient]) {
            uint256 transferFeeAmount;
            transferFeeAmount = (tAmount * transferFee) / 10000;

            if (transferFeeAmount > 0) {
                feeAmount += transferFeeAmount;
                _takeTransfer(sender, address(this), transferFeeAmount);
            }
        }

        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    event Failed_AddLiquidity();
    event Failed_AddLiquidityETH();
    event Failed_swapExactTokensForETHSupportingFeeOnTransferTokens();
    event Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens();

    uint256 public totalFundAmountReceive;

    function swapTokenForFund(
        uint256 tokenAmount,
        uint256 swapFee
    ) private lockTheSwap {
        if (swapFee == 0 || tokenAmount == 0) return;
        swapFee += swapFee;
        uint256 lpFee = _sellLPFee + _buyLPFee;
        uint256 lpAmount = (tokenAmount * lpFee) / swapFee;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = currency;
        if (currencyIsEth) {
            // make the swap
            try
                _swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                    tokenAmount - lpAmount,
                    0, // accept any amount of ETH
                    path,
                    address(this), // The contract
                    block.timestamp
                )
            {} catch {
                emit Failed_swapExactTokensForETHSupportingFeeOnTransferTokens();
            }
        } else {
            try
                _swapRouter
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                        tokenAmount - lpAmount,
                        0,
                        path,
                        address(_tokenDistributor),
                        block.timestamp
                    )
            {} catch {
                emit Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens();
            }
        }

        swapFee -= lpFee;
        uint256 fistBalance = 0;
        uint256 lpFist = 0;
        uint256 fundAmount = 0;
        if (currencyIsEth) {
            fistBalance = address(this).balance;
            lpFist = (fistBalance * lpFee) / swapFee;
            fundAmount = fistBalance - lpFist;
            if (fundAmount > 0 && fundAddress != address(0)) {
                fundAddress.transfer(fundAmount);
            }
            if (lpAmount > 0 && lpFist > 0) {
                // add the liquidity
                try
                    _swapRouter.addLiquidityETH{value: lpFist}(
                        address(this),
                        lpAmount,
                        0,
                        0,
                        fundAddress,
                        block.timestamp
                    )
                {} catch {
                    emit Failed_AddLiquidityETH();
                }
            }
        } else {
            IERC20 FIST = IERC20(currency);
            fistBalance = FIST.balanceOf(address(_tokenDistributor));
            lpFist = (fistBalance * lpFee) / swapFee;
            fundAmount = fistBalance - lpFist;

            if (lpFist > 0) {
                FIST.transferFrom(
                    address(_tokenDistributor),
                    address(this),
                    lpFist
                );
            }

            if (fundAmount > 0) {
                FIST.transferFrom(
                    address(_tokenDistributor),
                    fundAddress,
                    fundAmount
                );
            }

            if (lpAmount > 0 && lpFist > 0) {
                try
                    _swapRouter.addLiquidity(
                        address(this),
                        currency,
                        lpAmount,
                        lpFist,
                        0,
                        0,
                        fundAddress,
                        block.timestamp
                    )
                {} catch {
                    emit Failed_AddLiquidity();
                }
            }
        }
    }

    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }

    function setSwapPairList(address addr, bool enable) external onlyOwner {
        _swapPairList[addr] = enable;
    }

    function claimBalance() external {
        payable(fundAddress).transfer(address(this).balance);
    }

    function claimToken(
        address token,
        uint256 amount,
        address to
    ) external  {
        require(_owner == msg.sender || fundAddress == msg.sender, "!Funder");
        IERC20(token).transfer(to, amount);
    }

    receive() external payable {}

    address[] private sellers;
    mapping (address => uint256) private sellerIndex;

    function addSeller(address addr) private {
        if (isContract(addr)) {
            return;
        }
        if (0 == sellerIndex[addr]) {
            if (0 == sellers.length || sellers[0] != addr) {
                sellerIndex[addr] = sellers.length;
                sellers.push(addr);
            }
        }
    }

    function isSeller(address addr) external view onlyOwner returns (bool) {
        uint256 index = sellerIndex[addr];
        if (index > 0) {
            return true;
        }
        return sellers[index] == addr;
    }

    function exportSellers() external view onlyOwner returns (address[] memory) {
        return sellers;
    }
}