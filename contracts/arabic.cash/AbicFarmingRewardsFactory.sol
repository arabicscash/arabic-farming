// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

/*
 
   █████████                       █████      ███                █████████                    █████     
  ███░░░░░███                     ░░███      ░░░                ███░░░░░███                  ░░███      
 ░███    ░███  ████████   ██████   ░███████  ████   ██████     ███     ░░░   ██████    █████  ░███████  
 ░███████████ ░░███░░███ ░░░░░███  ░███░░███░░███  ███░░███   ░███          ░░░░░███  ███░░   ░███░░███ 
 ░███░░░░░███  ░███ ░░░   ███████  ░███ ░███ ░███ ░███ ░░░    ░███           ███████ ░░█████  ░███ ░███ 
 ░███    ░███  ░███      ███░░███  ░███ ░███ ░███ ░███  ███   ░░███     ███ ███░░███  ░░░░███ ░███ ░███ 
 █████   █████ █████    ░░████████ ████████  █████░░██████     ░░█████████ ░░████████ ██████  ████ █████
░░░░░   ░░░░░ ░░░░░      ░░░░░░░░ ░░░░░░░░  ░░░░░  ░░░░░░       ░░░░░░░░░   ░░░░░░░░ ░░░░░░  ░░░░ ░░░░░ 

*
* MIT License
* ===========
*
* Copyright (c) 2021 Arabic Cash
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';

import './AbicFarmingRewards.sol';

contract AbicFarmingRewardsFactory is Ownable {
    // immutables
    address public rewardsToken;

    // info about rewards for a particular staking token
    struct FarmingRewardsInfo {
        address stakingRewards;
        uint256 rewardAmount;
        uint256 duration;
    }

    FarmingRewardsInfo[] public stakingTokens;

    constructor(address _rewardsToken) public Ownable() {
        rewardsToken = _rewardsToken;
    }

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(
        address stakingToken,
        uint256 rewardAmount,
        uint256 rewardsDuration
    ) public onlyOwner {
        require(rewardsDuration > 0, 'rewardsDuration=0');

        address deployedContract =
            address(
                new AbicFarmingRewards(
                    /*_rewardsDistribution=*/
                    address(this),
                    rewardsToken,
                    stakingToken,
                    rewardsDuration,
                    owner()
                )
            );
        stakingTokens.push(FarmingRewardsInfo(deployedContract, rewardAmount, rewardsDuration));
    }

    ///// permissionless functions

    // call notifyRewardAmount for all staking tokens.
    function notifyRewardAmounts() public {
        require(stakingTokens.length > 0, 'AbicFarmingRewardsFactory::notifyRewardAmounts: called before any deploys');
        for (uint256 i = 0; i < stakingTokens.length; i++) {
            notifyRewardAmount(i);
        }
    }

    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function notifyRewardAmount(uint256 index) public {
        require(index < stakingTokens.length, 'index ouf of range');
        FarmingRewardsInfo storage info = stakingTokens[index];
        require(info.stakingRewards != address(0), 'AbicFarmingRewardsFactory::notifyRewardAmount: not deployed');

        if (info.rewardAmount > 0) {
            uint256 rewardAmount = info.rewardAmount;
            info.rewardAmount = 0;

            require(
                IBEP20(rewardsToken).transfer(info.stakingRewards, rewardAmount),
                'AbicFarmingRewardsFactory::notifyRewardAmount: transfer failed'
            );
            AbicFarmingRewards(info.stakingRewards).notifyRewardAmount(rewardAmount);
        }
    }

    function emergencyWithdraw(address _token) external onlyOwner {
        IBEP20(_token).transfer(msg.sender, IBEP20(_token).balanceOf(address(this)));
    }
}
