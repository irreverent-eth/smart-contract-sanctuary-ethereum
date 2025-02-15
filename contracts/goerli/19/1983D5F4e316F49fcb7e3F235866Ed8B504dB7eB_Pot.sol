// SPDX-License-Identifier: AGPL-3.0-or-later

/// pot.sol -- USB Savings Rate

// Copyright (C) 2018 Rain <[email protected]>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

/*
   "Savings USB" is obtained when USB is deposited into
   this contract. Each "Savings USB" accrues USB interest
   at the "USB Savings Rate".

   This contract does not implement a user tradeable token
   and is intended to be used with adapters.

         --- `save` your `USB` in the `pot` ---

   - `dsr`: the USB Savings Rate
   - `pie`: user balance of Savings USB

   - `join`: start saving some USB
   - `exit`: remove some USB
   - `drip`: perform rate collection

*/

interface VatLike {
    function move(address,address,uint256) external;
    function suck(address,address,uint256) external;
}

contract Pot {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1; }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Pot/not-authorized");
        _;
    }

    // --- Data ---
    mapping (address => uint256) public pie;  // Normalised Savings USB [wad]
    mapping (address => uint256) public balance;

    uint256 public Pie;   // Total Normalised Savings USB  [wad]
    uint256 public totalDeposit;
    uint256 public dsr;   // The USB Savings Rate          [ray]
    uint256 public chi;   // The Rate Accumulator          [ray]

    VatLike public vat;   // CDP Engine
    address public vow;   // Debt Engine
    uint256 public rho;   // Time of last drip     [unix epoch time]

    uint256 public live;  // Active Flag

    event SetDsr(uint newDsr);
    event SetVow(address vow);
    event Cage(uint live, uint dsr);
    event Drip(uint chi_, uint chi, uint rho);
    event Join(address urn, uint wad, uint depositWad, uint chi);
    event Exit(address urn, uint wad, uint withdrawWad, uint chi);

    // --- Init ---
    constructor(address vat_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        dsr = ONE;
        chi = ONE;
        rho = block.timestamp;
        live = 1;
    }

    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, base)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Administration ---
    function setDsr(uint256 _dsr) external auth {
        require(live == 1, "Pot/not-live");
        // require(block.timestamp == rho, "Pot/rho-not-updated");
        rho = block.timestamp;
        dsr = _dsr;
        emit SetDsr(_dsr);
    }

    function setVow(address addr) external auth {
        require(addr != address(0), "Pot/invalid-address");
        vow = addr;
        emit SetVow(addr);
    }

    function cage() external auth {
        live = 0;
        dsr = ONE;
        emit Cage(live, dsr);
    }

    // --- Savings Rate Accumulation ---
    function drip() external returns (uint tmp) {
        require(block.timestamp >= rho, "Pot/invalid-now");
        tmp = rmul(rpow(dsr, block.timestamp - rho, ONE), chi);
        uint chi_ = sub(tmp, chi);
        chi = tmp;
        rho = block.timestamp;
        vat.suck(address(vow), address(this), mul(Pie, chi_));
        emit Drip(chi_, chi, rho);
    }

    // --- Savings USB Management ---
    function join(uint wad, uint wadDeposit, uint chi_) external {
        require(block.timestamp == rho, "Pot/rho-not-updated");
        pie[msg.sender] = add(pie[msg.sender], wad);
        Pie             = add(Pie,             wad);
        balance[msg.sender] = add(balance[msg.sender], wadDeposit);
        totalDeposit = add(totalDeposit, wadDeposit);
        vat.move(msg.sender, address(this), mul(chi, wad));
        emit Join(msg.sender, wad, wadDeposit, chi_);
    }

    function exit(uint wad, uint wadWithdraw, uint chi_) external {  
        pie[msg.sender] = sub(pie[msg.sender], wad);
        Pie             = sub(Pie,             wad);
        balance[msg.sender] = sub(balance[msg.sender], wadWithdraw);
        totalDeposit = sub(totalDeposit, wadWithdraw);
        vat.move(address(this), msg.sender, mul(chi, wad));
        emit Exit(msg.sender, wad, wadWithdraw, chi_);
    }
}