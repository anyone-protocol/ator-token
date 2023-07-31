// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC20.sol";

contract ATOR is ERC20, Ownable {
  uint256 public maxBuyAmount;
  uint256 public maxSellAmount;
  uint256 public maxWallet;

  // IDexRouter public dexRouter;
  address public lpPair;

  bool private swapping;
  uint256 public swapTokensAtAmount;

  address public operationsAddress;
  address public treasuryAddress;

  uint256 public tradingActiveBlock = 0; // 0 means trading is not active
  uint256 public blockForPenaltyEnd;
  mapping(address => bool) public boughtEarly;
  address[] public identifiedBots;
  uint256 public botsCaught;

  bool public limitsInEffect = true;
  bool public tradingActive = false;
  bool public swapEnabled = false;

  // Anti-bot and anti-whale mappings and variables
  mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
  bool public transferDelayEnabled = true;

  uint256 public buyTotalFees;
  uint256 public buyOperationsFee;
  uint256 public buyLiquidityFee;
  uint256 public buyTreasuryFee;

  uint256 public sellTotalFees;
  uint256 public sellOperationsFee;
  uint256 public sellLiquidityFee;
  uint256 public sellTreasuryFee;

  uint256 public tokensForOperations;
  uint256 public tokensForLiquidity;
  uint256 public tokensForTreasury;
  bool public markBotsEnabled = true;
  bool private taxFree = true; 

  /******************/

  // exlcude from fees and max transaction amount
  mapping(address => bool) private _isExcludedFromFees;
  mapping(address => bool) public _isExcludedMaxTransactionAmount;

  // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
  // could be subject to a maximum transfer amount
  mapping(address => bool) public automatedMarketMakerPairs;

  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

  event EnabledTrading();

  event ExcludeFromFees(address indexed account, bool isExcluded);

  event UpdatedMaxBuyAmount(uint256 newAmount);

  event UpdatedMaxSellAmount(uint256 newAmount);

  event UpdatedMaxWalletAmount(uint256 newAmount);

  event UpdatedOperationsAddress(address indexed newWallet);

  event UpdatedTreasuryAddress(address indexed newWallet);

  event MaxTransactionExclusion(address _address, bool excluded);

  event OwnerForcedSwapBack(uint256 timestamp);

  event BotBlocked(address sniper);

  event SwapAndLiquify(
    uint256 tokensSwapped,
    uint256 ethReceived,
    uint256 tokensIntoLiquidity
  );

  event TransferForeignToken(address token, uint256 amount);

  event UpdatedPrivateMaxSell(uint256 amount);

  event EnabledSelling();

  constructor() payable ERC20("AirTor Protocol", "ATOR") {
    address newOwner = msg.sender; 

    // address _dexRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; 

    // initialize router
    // dexRouter = IDexRouter(_dexRouter);

    // create pair
    // lpPair = IDexFactory(dexRouter.factory()).createPair(
    //   address(this),
    //   dexRouter.WETH()
    // );
    // _excludeFromMaxTransaction(address(lpPair), true);
    // _setAutomatedMarketMakerPair(address(lpPair), true);

    uint256 totalSupply = 100 * 1e6 * 1e18; // 100 million

    maxBuyAmount = (totalSupply * 2) / 100; // 2%
    maxSellAmount = (totalSupply * 2) / 100; // 2%
    maxWallet = (totalSupply * 2) / 100; // 2%
    swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05 %

    buyOperationsFee = 2;
    buyLiquidityFee = 0;
    buyTreasuryFee = 3;
    buyTotalFees = buyOperationsFee + buyLiquidityFee + buyTreasuryFee;

    sellOperationsFee = 2;
    sellLiquidityFee = 0;
    sellTreasuryFee = 3;
    sellTotalFees = sellOperationsFee + sellLiquidityFee + sellTreasuryFee;

    operationsAddress = address(msg.sender);
    treasuryAddress = address(0x7ccA2562ff85bdD45eD4BB99ccf32148AD45EA35);

    _excludeFromMaxTransaction(newOwner, true);
    _excludeFromMaxTransaction(address(this), true);
    _excludeFromMaxTransaction(address(0xdead), true);
    _excludeFromMaxTransaction(address(operationsAddress), true);
    _excludeFromMaxTransaction(address(treasuryAddress), true);
    // _excludeFromMaxTransaction(address(dexRouter), true);

    excludeFromFees(newOwner, true);
    excludeFromFees(address(this), true);
    excludeFromFees(address(0xdead), true);
    excludeFromFees(address(operationsAddress), true);
    excludeFromFees(address(treasuryAddress), true);
    // excludeFromFees(address(dexRouter), true);

    _createInitialSupply(newOwner, (totalSupply * 75) / 100); // Tokens for liquidity 
    _createInitialSupply(address(this), (totalSupply * 25) / 100); // Special fee system

    transferOwnership(newOwner);
  }

  receive() external payable {}

  function enableTrading(uint256 blocksForPenalty) external onlyOwner {
    require(!tradingActive, "Cannot reenable trading");
    require(
      blocksForPenalty <= 10,
      "Cannot make penalty blocks more than 10"
    );
    tradingActive = true;
    swapEnabled = true;
    tradingActiveBlock = block.number;
    blockForPenaltyEnd = tradingActiveBlock + blocksForPenalty;
    emit EnabledTrading();
  }

  function getEarlyBuyers() external view returns (address[] memory) {
    return identifiedBots;
  }

  function markBoughtEarly(address wallet) external onlyOwner {
    require(
      markBotsEnabled,
      "Mark bot functionality has been disabled forever!"
    );
    require(!boughtEarly[wallet], "Wallet is already flagged.");
    boughtEarly[wallet] = true;
  }

  function removeBoughtEarly(address wallet) external onlyOwner {
    require(boughtEarly[wallet], "Wallet is already not flagged.");
    boughtEarly[wallet] = false;
  }

  // function emergencyUpdateRouter(address router, bool _swapEnabled) external onlyOwner {
  //   require(!tradingActive, "Cannot update after trading is functional");
  //   dexRouter = IDexRouter(router);
  //   swapEnabled = _swapEnabled; 
  // }

  // disable Transfer delay - cannot be reenabled
  function disableTransferDelay() external onlyOwner {
    transferDelayEnabled = false;
  }

  function updateMaxBuyAmount(uint256 newNum) external onlyOwner {
    require(
      newNum >= ((totalSupply() * 5) / 1000) / 1e18,
      "Cannot set max buy amount lower than 0.5%"
    );
    require(
      newNum <= ((totalSupply() * 2) / 100) / 1e18,
      "Cannot set buy sell amount higher than 2%"
    );
    maxBuyAmount = newNum * (10**18);
    emit UpdatedMaxBuyAmount(maxBuyAmount);
  }

  function setTaxFree(bool set) external onlyOwner {
    taxFree = set; 
  }

  function updateMaxSellAmount(uint256 newNum) external onlyOwner {
    require(
      newNum >= ((totalSupply() * 5) / 1000) / 1e18,
      "Cannot set max sell amount lower than 0.5%"
    );
    require(
      newNum <= ((totalSupply() * 2) / 100) / 1e18,
      "Cannot set max sell amount higher than 2%"
    );
    maxSellAmount = newNum * (10**18);
    emit UpdatedMaxSellAmount(maxSellAmount);
  }

  function updateMaxWalletAmount(uint256 newNum) external onlyOwner {
    require(
      newNum >= ((totalSupply() * 5) / 1000) / 1e18,
      "Cannot set max wallet amount lower than 0.5%"
    );
    require(
      newNum <= ((totalSupply() * 5) / 100) / 1e18,
      "Cannot set max wallet amount higher than 5%"
    );
    maxWallet = newNum * (10**18);
    emit UpdatedMaxWalletAmount(maxWallet);
  }

  // change the minimum amount of tokens to sell from fees
  function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
    require(
      newAmount >= (totalSupply() * 1) / 100000,
      "Swap amount cannot be lower than 0.001% total supply."
    );
    require(
      newAmount <= (totalSupply() * 1) / 1000,
      "Swap amount cannot be higher than 0.1% total supply."
    );
    swapTokensAtAmount = newAmount;
  }

  function _excludeFromMaxTransaction(address updAds, bool isExcluded) private {
    _isExcludedMaxTransactionAmount[updAds] = isExcluded;
    emit MaxTransactionExclusion(updAds, isExcluded);
  }

  function excludeFromMaxTransaction(address updAds, bool isEx)
    external
    onlyOwner
  {
    if (!isEx) {
      require(
        updAds != lpPair,
        "Cannot remove uniswap pair from max txn"
      );
    }
    _isExcludedMaxTransactionAmount[updAds] = isEx;
  }

  function setAutomatedMarketMakerPair(address pair, bool value)
    external
    onlyOwner
  {
    require(
      pair != lpPair,
      "The pair cannot be removed from automatedMarketMakerPairs"
    );
    _setAutomatedMarketMakerPair(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function _setAutomatedMarketMakerPair(address pair, bool value) private {
    automatedMarketMakerPairs[pair] = value;
    _excludeFromMaxTransaction(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function updateBuyFees(
    uint256 _operationsFee,
    uint256 _liquidityFee,
    uint256 _treasuryFee
  ) external onlyOwner {
    buyOperationsFee = _operationsFee;
    buyLiquidityFee = _liquidityFee;
    buyTreasuryFee = _treasuryFee;
    buyTotalFees = buyOperationsFee + buyLiquidityFee + buyTreasuryFee;
    require(buyTotalFees <= 20, "Must keep fees at 20% or less");
  }

  function updateSellFees(
    uint256 _operationsFee,
    uint256 _liquidityFee,
    uint256 _treasuryFee
  ) external onlyOwner {
    sellOperationsFee = _operationsFee;
    sellLiquidityFee = _liquidityFee;
    sellTreasuryFee = _treasuryFee;
    sellTotalFees = sellOperationsFee + sellLiquidityFee + sellTreasuryFee;
    require(sellTotalFees <= 30, "Must keep fees at 30% or less");
  }

  function excludeFromFees(address account, bool excluded) public onlyOwner {
    _isExcludedFromFees[account] = excluded;
    emit ExcludeFromFees(account, excluded);
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "amount must be greater than 0");

    if (!tradingActive) {
      require(
        _isExcludedFromFees[from] || _isExcludedFromFees[to],
        "Trading is not active."
      );
    }

    if (!earlyBuyPenaltyInEffect() && tradingActive) {
      require(
        !boughtEarly[from] || to == owner() || to == address(0xdead),
        "Bots cannot transfer tokens in or out except to owner or dead address."
      );
    }

    if (limitsInEffect) {
      if (
        from != owner() &&
        to != owner() &&
        to != address(0xdead) &&
        !_isExcludedFromFees[from] &&
        !_isExcludedFromFees[to]
      ) {
        if (transferDelayEnabled) {
          // if (to != address(dexRouter) && to != address(lpPair)) {
            require(
              _holderLastTransferTimestamp[tx.origin] <
                block.number - 2 &&
                _holderLastTransferTimestamp[to] <
                block.number - 2,
              "_transfer:: Transfer Delay enabled.  Try again later."
            );
            _holderLastTransferTimestamp[tx.origin] = block.number;
            _holderLastTransferTimestamp[to] = block.number;
          // }
        }

        //when buy
        if (
          automatedMarketMakerPairs[from] &&
          !_isExcludedMaxTransactionAmount[to]
        ) {
          require(
            amount <= maxBuyAmount,
            "Buy transfer amount exceeds the max buy."
          );
          require(
            amount + balanceOf(to) <= maxWallet,
            "Max Wallet Exceeded"
          );
        }
        //when sell
        else if (
          automatedMarketMakerPairs[to] &&
          !_isExcludedMaxTransactionAmount[from]
        ) {
          require(
            amount <= maxSellAmount,
            "Sell transfer amount exceeds the max sell."
          );
        } else if (!_isExcludedMaxTransactionAmount[to]) {
          require(
            amount + balanceOf(to) <= maxWallet,
            "Max Wallet Exceeded"
          );
        }
      }
    }

    uint256 contractTokenBalance = balanceOf(address(this));

    bool canSwap = contractTokenBalance >= swapTokensAtAmount;

    if (
      canSwap && swapEnabled && !swapping && automatedMarketMakerPairs[to]
    ) {
      swapping = true;
      swapBack();
      swapping = false;
    }

    bool takeFee = true;
    // if any account belongs to _isExcludedFromFee account then remove the fee
    if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
      takeFee = false;
    }

    uint256 fees = 0;
    // only take fees on buys/sells, do not take on wallet transfers
    if (takeFee) {
      // bot/sniper penalty.
      if (
        (earlyBuyPenaltyInEffect()) &&
        automatedMarketMakerPairs[from] &&
        !automatedMarketMakerPairs[to] &&
        !_isExcludedFromFees[to] &&
        buyTotalFees > 0
      ) {
        if (!boughtEarly[to]) {
          boughtEarly[to] = true;
          botsCaught += 1;
          identifiedBots.push(to);
          emit BotBlocked(to);
        }

        fees = (amount * 80) / 100;
        tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
        tokensForOperations += (fees * buyOperationsFee) / buyTotalFees;
        tokensForTreasury += (fees * buyTreasuryFee) / buyTotalFees;
      }

      // on sell
      else if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
        fees = (amount * sellTotalFees) / 100;
        tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
        tokensForOperations +=
          (fees * sellOperationsFee) /
          sellTotalFees;
        tokensForTreasury += (fees * sellTreasuryFee) / sellTotalFees;
      }
      // on buy
      else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
        fees = (amount * buyTotalFees) / 100;
        tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
        tokensForOperations += (fees * buyOperationsFee) / buyTotalFees;
        tokensForTreasury += (fees * buyTreasuryFee) / buyTotalFees;
      }
        
      if(!taxFree) {

        if (fees > 0) {
            super._transfer(from, address(this), fees);
        }

        amount -= fees;
      }
    }

    super._transfer(from, to, amount);
  }

  function earlyBuyPenaltyInEffect() public view returns (bool) {
    return block.number < blockForPenaltyEnd;
  }

  function swapTokensForEth(uint256 tokenAmount) private {
    // // generate the uniswap pair path of token -> weth
    // address[] memory path = new address[](2);
    // path[0] = address(this);
    // path[1] = dexRouter.WETH();

    // _approve(address(this), address(dexRouter), tokenAmount);

    // // make the swap
    // dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
    //   tokenAmount,
    //   0, // accept any amount of ETH
    //   path,
    //   address(this),
    //   block.timestamp
    // );
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    // // approve token transfer to cover all possible scenarios
    // _approve(address(this), address(dexRouter), tokenAmount);

    // // add the liquidity
    // dexRouter.addLiquidityETH{value: ethAmount}(
    //   address(this),
    //   tokenAmount,
    //   0, // slippage is unavoidable
    //   0, // slippage is unavoidable
    //   address(0xdead),
    //   block.timestamp
    // );
  }

  function swapBack() private {
    uint256 contractBalance = balanceOf(address(this));

    uint256 totalTokensToSwap = tokensForLiquidity +
      tokensForOperations +
      tokensForTreasury;

    uint256 trueTokensToSwap = contractBalance < totalTokensToSwap ? contractBalance : totalTokensToSwap; 

    if (trueTokensToSwap == 0) {
        return;
    }

    if (trueTokensToSwap > swapTokensAtAmount * 30) {
      trueTokensToSwap = swapTokensAtAmount * 30;
    }

    bool success;

    // Halve the amount of liquidity tokens
    uint256 liquidityTokens = (trueTokensToSwap * tokensForLiquidity) /
        totalTokensToSwap /
        2;

    swapTokensForEth(trueTokensToSwap - liquidityTokens);

    uint256 ethBalance = address(this).balance;
    uint256 ethForLiquidity = ethBalance;

    uint256 ethForOperations = (ethBalance * tokensForOperations) /
        (totalTokensToSwap - (tokensForLiquidity / 2));
    uint256 ethForTreasury = (ethBalance * tokensForTreasury) /
        (totalTokensToSwap - (tokensForLiquidity / 2));

    ethForLiquidity -= ethForOperations + ethForTreasury;

    tokensForLiquidity = 0;
    tokensForOperations = 0;
    tokensForTreasury = 0;

    if (liquidityTokens > 0 && ethForLiquidity > 0) {
        addLiquidity(liquidityTokens, ethForLiquidity);
    }

    (success, ) = address(treasuryAddress).call{value: ethForTreasury}("");
    (success, ) = address(operationsAddress).call{
      value: address(this).balance
    }("");
  }

  function transferForeignToken(address _token, address _to)
    external
    onlyOwner
    returns (bool _sent)
  {
    require(_token != address(0), "_token address cannot be 0");
    require(
      _token != address(this) || !tradingActive,
      "Can't withdraw native tokens while trading is active"
    );
    uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
    _sent = IERC20(_token).transfer(_to, _contractBalance);
    emit TransferForeignToken(_token, _contractBalance);
  }

  // withdraw ETH if stuck or someone sends to the address
  function withdrawStuckETH() external onlyOwner {
    bool success;
    (success, ) = address(msg.sender).call{value: address(this).balance}("");
  }

  function setOperationsAddress(address _operationsAddress)
    external
    onlyOwner
  {
    require(
      _operationsAddress != address(0),
      "_operationsAddress address cannot be 0"
    );
    operationsAddress = payable(_operationsAddress);
    emit UpdatedOperationsAddress(_operationsAddress);
  }

  function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
    require(
      _treasuryAddress != address(0),
      "_operationsAddress address cannot be 0"
    );
    treasuryAddress = payable(_treasuryAddress);
    emit UpdatedTreasuryAddress(_treasuryAddress);
  }

  // force Swap back if slippage issues.
  function forceSwapBack() external onlyOwner {
    require(
      balanceOf(address(this)) >= swapTokensAtAmount,
      "Can only swap when token amount is at or higher than restriction"
    );
    swapping = true;
    swapBack();
    swapping = false;
    emit OwnerForcedSwapBack(block.timestamp);
  }

  // remove limits after token is stable
  function removeLimits() external onlyOwner {
    limitsInEffect = false;
  }

  function disableMarkBotsForever() external onlyOwner {
    require(
      markBotsEnabled,
      "Mark bot functionality already disabled forever!!"
    );

    markBotsEnabled = false;
  }

  function launch(uint256 blocksForPenalty) external onlyOwner {
    require(!tradingActive, "Trading is already active, cannot relaunch.");
    require(
      blocksForPenalty < 10,
      "Cannot make penalty blocks more than 10"
    );

    //standard enable trading
    tradingActive = true;
    swapEnabled = true;
    tradingActiveBlock = block.number;
    blockForPenaltyEnd = tradingActiveBlock + blocksForPenalty;
    emit EnabledTrading();
  }
}