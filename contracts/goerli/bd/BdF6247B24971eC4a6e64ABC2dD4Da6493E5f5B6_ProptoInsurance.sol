// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Tokens/IToken.sol";
import "../Interfaces/IProptoInsurance.sol";
import "../Interfaces/IProptoPredictFactory.sol";
import "../Interfaces/IProptoPredict.sol";
import "../Interfaces/IPVRF.sol";

contract ProptoInsurance is IProptoInsurance, Ownable {
    uint8 ISTATUS_UNDERWRITING = 0;
    uint8 ISTATUS_DONESETTLEMENT = 1;
    uint8 ISTATUS_EXPIRED = 2;
    uint8 ISTATUS_PROCESSING = 3;

    using SafeMath for uint256;

    using Counters for Counters.Counter;

    // this is Insurance Provider Token contract address
    address public ITokenContract;

    address public reservesContract;

    address public proptoPredictFactoryContract;

    mapping(address => inoutReservesDetails) public inoutReservesMap;

    mapping(uint256 => incomingReservesAmount) public incomingReservesAmountMap;

    mapping(uint256 => outgoingReservesAmount) public outgoingReservesAmountMap;

    Counters.Counter private _PVRFIndexCounter;

    mapping(uint256 => address) public PVRFS;

    mapping(uint256 => uint8) public suspendedPVRFS;

    address public standardPVRF;

    mapping(uint256 => mapping(uint256 => RoundLockReserves))
        public roundLockReserveses;

    mapping(uint256 => uint256) public nextVRFRounds;

    uint256 public _nextResizeReservesVRFIndex;

    uint256 public totalReserves;

    uint256 public totalLockedReserves;

    uint256 public totalSettlementReserves;

    // PVRFContractIndex PVRFIndex ProptoEventContract customId
    mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => uint256))))
        public proptoPredictCustomIdGroupsMap;

    mapping(uint256 => mapping(uint256 => Counters.Counter))
        public proptoPredictCustomIdGroupsIndexCounter;

    mapping(uint256 => mapping(uint256 => mapping(uint256 => proptoPredictCustomIdGroup)))
        public proptoPredictCustomIdGroups;

    Counters.Counter private _insuranceDataCounter;

    mapping(uint256 => insuranceData) public insuranceDatas;

    constructor(
        address _reservesContract,
        address _ProptoPredictFactoryContract,
        address _standardPVRF
    ) {
        IToken iToken = new IToken();
        ITokenContract = address(iToken);
        reservesContract = _reservesContract;
        proptoPredictFactoryContract = _ProptoPredictFactoryContract;
        addPVRFWhite(_standardPVRF);
        setStandardPVRF(_standardPVRF);
        _nextResizeReservesVRFIndex = IPVRF(_standardPVRF).getPresentIndex();
    }

    function initPool(uint256 amount) public onlyOwner {
        require(totalReserves == 0, "already initialed");
        IERC20(reservesContract).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        IToken(ITokenContract).mint(msg.sender, amount);
        totalReserves = amount;
    }

    function getITokenValue() public view returns (uint256) {
        return
            IERC20(reservesContract).balanceOf(address(this)) /
            IToken(ITokenContract).totalSupply();
    }

    function getReservesValue() public view returns (uint256) {
        return
            IToken(ITokenContract).totalSupply() /
            IERC20(reservesContract).balanceOf(address(this));
    }

    function addInsuranceShare(uint256 amount) public {
        require(
            IERC20(reservesContract).balanceOf(msg.sender) >= amount,
            "reserves token balance not enough"
        );
        require(
            _nextResizeReservesVRFIndex ==
                IPVRF(standardPVRF).getPresentIndex(),
            "Previous round reserves not resized"
        );
        IERC20(reservesContract).transfer(address(this), amount);
        incomingReservesAmountMap[_nextResizeReservesVRFIndex].amount += amount;
        inoutReservesMap[msg.sender].detailNum++;
        inoutReservesMap[msg.sender]
            .list[inoutReservesMap[msg.sender].detailNum]
            .amount = amount;
        inoutReservesMap[msg.sender]
            .list[inoutReservesMap[msg.sender].detailNum]
            .PVRFIndex = _nextResizeReservesVRFIndex;
        inoutReservesMap[msg.sender]
            .list[inoutReservesMap[msg.sender].detailNum]
            .direction = true;

        emit InOutReserves(
            msg.sender,
            true,
            amount,
            0,
            _nextResizeReservesVRFIndex,
            inoutReservesMap[msg.sender].detailNum
        );
    }

    function removeInsuranceShare(uint256 amount) public {
        require(
            IToken(ITokenContract).balanceOf(msg.sender) >= amount,
            "iptoken balance not enough"
        );
        require(
            _nextResizeReservesVRFIndex ==
                IPVRF(standardPVRF).getPresentIndex(),
            "Previous round reserves not resized"
        );
        IToken(ITokenContract).transfer(address(this), amount);
        outgoingReservesAmountMap[_nextResizeReservesVRFIndex]
            .ITokenAmount += amount;
        inoutReservesMap[msg.sender].detailNum++;
        inoutReservesMap[msg.sender]
            .list[inoutReservesMap[msg.sender].detailNum]
            .ITokenAmount = amount;
        inoutReservesMap[msg.sender]
            .list[inoutReservesMap[msg.sender].detailNum]
            .PVRFIndex = _nextResizeReservesVRFIndex;
        inoutReservesMap[msg.sender]
            .list[inoutReservesMap[msg.sender].detailNum]
            .direction = false;

        emit InOutReserves(
            msg.sender,
            false,
            0,
            amount,
            _nextResizeReservesVRFIndex,
            inoutReservesMap[msg.sender].detailNum
        );
    }

    function collectInOutAsset(uint256 ListIndex) public {
        inoutReservesDetail memory iord = inoutReservesMap[msg.sender].list[
            ListIndex
        ];
        require(iord.PVRFIndex > 0, "list index error");
        require(iord.collected == false, "you have already collected");
        if (iord.direction == true) {
            require(
                incomingReservesAmountMap[iord.PVRFIndex].ITokenAmount > 0,
                "nothing to collect"
            );
            uint256 amount = (incomingReservesAmountMap[iord.PVRFIndex]
                .ITokenAmount * iord.amount) /
                incomingReservesAmountMap[iord.PVRFIndex].amount;
            inoutReservesMap[msg.sender].list[ListIndex].collected = true;
            inoutReservesMap[msg.sender].list[ListIndex].ITokenAmount = amount;
            IToken(ITokenContract).transferFrom(
                address(this),
                msg.sender,
                amount
            );
        } else {
            require(
                outgoingReservesAmountMap[iord.PVRFIndex].amount > 0,
                "nothing to collect"
            );
            uint256 amount = (outgoingReservesAmountMap[iord.PVRFIndex].amount *
                iord.ITokenAmount) /
                outgoingReservesAmountMap[iord.PVRFIndex].ITokenAmount;
            inoutReservesMap[msg.sender].list[ListIndex].collected = true;
            inoutReservesMap[msg.sender].list[ListIndex].amount = amount;
            IERC20(reservesContract).transferFrom(
                address(this),
                msg.sender,
                amount
            );
        }
    }

    function getInoutReservesCurrentIndex() public view returns (uint256) {
        return inoutReservesMap[msg.sender].detailNum;
    }

    function getInoutReservesDetail(uint256 ListIndex)
        public
        view
        returns (inoutReservesDetail memory)
    {
        inoutReservesDetail memory iord = inoutReservesMap[msg.sender].list[
            ListIndex
        ];
        if (
            iord.direction == true &&
            iord.ITokenAmount == 0 &&
            incomingReservesAmountMap[iord.PVRFIndex].ITokenAmount > 0
        ) {
            iord.ITokenAmount =
                (incomingReservesAmountMap[iord.PVRFIndex].ITokenAmount *
                    iord.amount) /
                incomingReservesAmountMap[iord.PVRFIndex].amount;
        }

        if (
            iord.direction == false &&
            iord.amount == 0 &&
            outgoingReservesAmountMap[iord.PVRFIndex].amount > 0
        ) {
            iord.amount =
                (outgoingReservesAmountMap[iord.PVRFIndex].amount *
                    iord.ITokenAmount) /
                outgoingReservesAmountMap[iord.PVRFIndex].ITokenAmount;
        }

        return iord;
    }

    function buyInsurance(
        address proptoPredictContract,
        uint256 tokenId,
        uint256 valuation,
        address applicant,
        address beneficiary,
        bool direction
    ) public {
        require(
            IProptoPredictFactory(proptoPredictFactoryContract)
                .validateProptoPredictAddress(proptoPredictContract),
            "invalid Propto Predict NFT"
        );
        ProptoPredictInfo memory ppi = IProptoPredict(proptoPredictContract)
            .getInfo(tokenId);

        uint256 PVRFContractIndex = getPVRFContractIndex(ppi.PVRFContract);

        uint256 VRFRANGE = IPVRF(ppi.PVRFContract).VRFRANGE();
        if (direction == false && ppi.amount == VRFRANGE) {
            require(true, "no range to buy");
        }

        uint256 presentIndex = IPVRF(ppi.PVRFContract).getPresentIndex();
        require(ppi.PVRFIndex == presentIndex, "Propto Predict not in present");

        require(
            presentIndex == nextVRFRounds[PVRFContractIndex],
            "PVRF Round not ready"
        );

        (uint256 payment, uint8 hour, ) = calcBuyInsurancePayment(
            ppi.PVRFContract,
            ppi.PVRFIndex,
            ppi.amount,
            valuation,
            direction
        );

        insuranceData memory ip = insuranceData(
            proptoPredictContract,
            tokenId,
            ppi.customId,
            valuation,
            applicant,
            beneficiary,
            direction,
            false,
            false,
            payment,
            hour,
            0
        );

        IERC20(reservesContract).transferFrom(
            msg.sender,
            address(this),
            ip.fee
        );

        setRoundLockReserves(ppi, ip.insuranceAmount, ip.direction);

        uint256 index = _insuranceDataCounter.current();
        insuranceDatas[index] = ip;
        _insuranceDataCounter.increment();

        emit ProptoInsuranceCreated(
            index,
            ip.proptoPredictContract,
            ip.tokenId,
            ppi.customId,
            ip.insuranceAmount,
            ip.applicant,
            ip.beneficiary,
            ip.direction,
            false,
            false,
            ip.fee,
            ip.time
        );

        uint256 proptoPredictCustomIdGroupsIndex = proptoPredictCustomIdGroupsMap[
                PVRFContractIndex
            ][ppi.PVRFIndex][ip.proptoPredictContract][ppi.customId];

        if (
            proptoPredictCustomIdGroups[PVRFContractIndex][ppi.PVRFIndex][
                proptoPredictCustomIdGroupsIndex
            ].proptoPredictContract == address(0)
        ) {
            proptoPredictCustomIdGroupsIndexCounter[PVRFContractIndex][
                ppi.PVRFIndex
            ].increment();
            proptoPredictCustomIdGroupsIndex = proptoPredictCustomIdGroupsIndexCounter[
                PVRFContractIndex
            ][ppi.PVRFIndex].current();
            proptoPredictCustomIdGroups[PVRFContractIndex][ppi.PVRFIndex][
                proptoPredictCustomIdGroupsIndex
            ].proptoPredictContract = proptoPredictContract;
            proptoPredictCustomIdGroups[PVRFContractIndex][ppi.PVRFIndex][
                proptoPredictCustomIdGroupsIndex
            ].customId = ppi.customId;
        }

        if (direction == true) {
            proptoPredictCustomIdGroups[PVRFContractIndex][ppi.PVRFIndex][
                proptoPredictCustomIdGroupsIndex
            ].indexes.push(index);
        } else {
            proptoPredictCustomIdGroups[PVRFContractIndex][ppi.PVRFIndex][
                proptoPredictCustomIdGroupsIndex
            ].reverseIndexes.push(index);
        }
    }

    function setRoundLockReserves(
        ProptoPredictInfo memory ppi,
        uint256 amount,
        bool direction
    ) private {
        uint256 PVRFContractIndex = getPVRFContractIndex(ppi.PVRFContract);

        uint256 VRFRANGE = IPVRF(ppi.PVRFContract).VRFRANGE();

        RoundLockRangeUnit[] memory ranges;
        if (ppi.startRange + ppi.amount > VRFRANGE) {
            if (direction == true) {
                ranges = new RoundLockRangeUnit[](2);
                ranges[0] = RoundLockRangeUnit(
                    0,
                    ppi.startRange + ppi.amount - VRFRANGE
                );
                ranges[1] = RoundLockRangeUnit(
                    ppi.startRange,
                    VRFRANGE - ppi.startRange
                );
            } else {
                ranges = new RoundLockRangeUnit[](1);
                ranges[0] = RoundLockRangeUnit(
                    ppi.startRange + ppi.amount - VRFRANGE,
                    VRFRANGE - ppi.amount
                );
            }
        } else {
            if (direction == true) {
                ranges = new RoundLockRangeUnit[](1);
                ranges[0] = RoundLockRangeUnit(ppi.startRange, ppi.amount);
            } else {
                if (ppi.startRange == 0) {
                    ranges = new RoundLockRangeUnit[](1);
                    ranges[0] = RoundLockRangeUnit(
                        ppi.startRange + ppi.amount,
                        VRFRANGE - ppi.amount
                    );
                } else if (ppi.startRange + ppi.amount == VRFRANGE) {
                    ranges = new RoundLockRangeUnit[](1);
                    ranges[0] = RoundLockRangeUnit(0, ppi.startRange);
                } else {
                    ranges = new RoundLockRangeUnit[](2);
                    ranges[0] = RoundLockRangeUnit(0, ppi.startRange);
                    ranges[1] = RoundLockRangeUnit(
                        ppi.startRange + ppi.amount,
                        VRFRANGE - ppi.startRange - ppi.amount
                    );
                }
            }
        }

        for (
            uint256 batchInfoIndex = 0;
            batchInfoIndex <
            roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex].batchesNum;
            batchInfoIndex++
        ) {
            if (
                roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                    .batchInfos[batchInfoIndex]
                    .batchLockedMaximum < amount
            ) {
                continue;
            }
            if (
                amount <
                roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                    .batchInfos[batchInfoIndex]
                    .batchLockedMaximum
                    .div(2)
            ) {
                break;
            }
            uint256 k = 0;
            uint256 insertedRangeTotal;
            RoundLockRangeUnit[] memory rangesNotInsert;

            for (uint256 i = 0; i < ranges.length; i++) {
                (
                    RoundLockRangeUnit[] memory rangesTemp,
                    uint256 insertedRange
                ) = insertBatchSlot(
                        ranges[i],
                        PVRFContractIndex,
                        ppi.PVRFIndex,
                        batchInfoIndex
                    );

                for (uint256 j = 0; j < rangesTemp.length; j++) {
                    assembly {
                        mstore(rangesNotInsert, add(mload(rangesNotInsert), 1))
                    }
                    rangesNotInsert[k] = rangesTemp[j];
                    k++;
                }
                insertedRangeTotal += insertedRange;
            }

            ranges = rangesNotInsert;
            if (insertedRangeTotal > 0) {
                roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                    .batchInfos[batchInfoIndex]
                    .batchRangeTotal += insertedRangeTotal;
                if (
                    amount >
                    roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                        .batchInfos[batchInfoIndex]
                        .batchLockedAmount
                ) {
                    uint256 amountDiff = roundLockReserveses[PVRFContractIndex][
                        ppi.PVRFIndex
                    ].batchInfos[batchInfoIndex].batchLockedAmount.sub(amount);
                    roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                        .batchInfos[batchInfoIndex]
                        .batchLockedAmount = amount;
                    roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                        .totalLockedAmount += amountDiff;
                    totalLockedReserves += amountDiff;
                }
            }
        }

        if (ranges.length > 0) {
            roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex].batchInfos[
                    roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                        .batchesNum
                ] = RoundLockReservesBatchInfo(
                ppi.amount,
                amount,
                amount.mul(2).sub(amount.div(2)),
                ranges.length,
                roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex].batchesNum
            );
            for (uint256 i = 0; i < ranges.length; i++) {
                roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                    .batchDatas[
                        roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                            .batchesNum
                    ]
                    .RoundLockRangeUnits[i] = ranges[i];
            }
            roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex].batchesNum++;
            roundLockReserveses[PVRFContractIndex][ppi.PVRFIndex]
                .totalLockedAmount += amount;
            totalLockedReserves += amount;
        }
    }

    function getRoundLockBatchRangeUnits(
        uint256 VRFMachineIndex,
        uint256 VRFIndex,
        uint256 dataIndex,
        uint256 index
    ) public view returns (RoundLockRangeUnit memory) {
        return
            roundLockReserveses[VRFMachineIndex][VRFIndex]
                .batchDatas[dataIndex]
                .RoundLockRangeUnits[index];
    }

    function getRoundLockReservesBatchInfo(
        uint256 VRFMachineIndex,
        uint256 VRFIndex,
        uint256 batchInfoIndex
    ) public view returns (RoundLockReservesBatchInfo memory) {
        return
            roundLockReserveses[VRFMachineIndex][VRFIndex].batchInfos[
                batchInfoIndex
            ];
    }

    function insertRoundLockRangeUnits(
        RoundLockRangeUnit memory unit,
        uint256 VRFMachineIndex,
        uint256 VRFIndex,
        uint256 batchInfoIndex
    ) private {
        RoundLockRangeUnit[] memory items = getRoundBatchDatas(
            VRFMachineIndex,
            VRFIndex,
            batchInfoIndex
        );
        uint256 index = items.length;
        assembly {
            mstore(items, add(mload(items), 1))
        }
        items[index] = unit;
        items = sortRoundBatchDataUnitsByRangeStart(items);

        for (uint256 k = 0; k < items.length; k++) {
            roundLockReserveses[VRFMachineIndex][VRFIndex]
                .batchDatas[
                    roundLockReserveses[VRFMachineIndex][VRFIndex]
                        .batchInfos[batchInfoIndex]
                        .dataIndex
                ]
                .RoundLockRangeUnits[k] = items[k];
        }
        roundLockReserveses[VRFMachineIndex][VRFIndex]
            .batchInfos[batchInfoIndex]
            .batchRangesUnitNum++;
        roundLockReserveses[VRFMachineIndex][VRFIndex]
            .batchInfos[batchInfoIndex]
            .batchRangeTotal += unit.rangeAmount;
    }

    function updateRoundLockRangeUnits(
        RoundLockRangeUnit memory unit,
        uint256 VRFMachineIndex,
        uint256 VRFIndex,
        uint256 batchInfoIndex,
        uint256 index
    ) private {
        uint256 dataIndex = roundLockReserveses[VRFMachineIndex][VRFIndex]
            .batchInfos[batchInfoIndex]
            .dataIndex;
        RoundLockRangeUnit memory item = getRoundLockBatchRangeUnits(
            VRFMachineIndex,
            VRFIndex,
            dataIndex,
            index
        );
        if (unit.rangeAmount >= item.rangeAmount) {
            roundLockReserveses[VRFMachineIndex][VRFIndex]
                .batchInfos[batchInfoIndex]
                .batchRangeTotal += unit.rangeAmount - item.rangeAmount;
        } else {
            roundLockReserveses[VRFMachineIndex][VRFIndex]
                .batchInfos[batchInfoIndex]
                .batchRangeTotal -= item.rangeAmount - unit.rangeAmount;
        }
        roundLockReserveses[VRFMachineIndex][VRFIndex]
            .batchDatas[dataIndex]
            .RoundLockRangeUnits[index] = unit;
    }

    function insertBatchSlot(
        RoundLockRangeUnit memory unit,
        uint256 VRFMachineIndex,
        uint256 VRFIndex,
        uint256 batchInfoIndex
    )
        private
        returns (
            RoundLockRangeUnit[] memory unitsNotInsert,
            uint256 insertedRangeTotal
        )
    {
        unitsNotInsert = new RoundLockRangeUnit[](0);

        RoundLockReservesBatchInfo memory info = getRoundLockReservesBatchInfo(
            VRFMachineIndex,
            VRFIndex,
            batchInfoIndex
        );
        uint256 unitIndex = 0;

        for (uint256 i = 0; i < info.batchRangesUnitNum; i++) {
            RoundLockRangeUnit memory item = getRoundLockBatchRangeUnits(
                VRFMachineIndex,
                VRFIndex,
                info.dataIndex,
                i
            );

            uint256 unitRangeEnd = unit.rangeStart + unit.rangeAmount - 1;
            uint256 itemRangeEnd = item.rangeStart + item.rangeAmount - 1;

            if (unit.rangeStart < item.rangeStart) {
                if (unitRangeEnd < item.rangeStart) {
                    insertRoundLockRangeUnits(
                        unit,
                        VRFMachineIndex,
                        VRFIndex,
                        batchInfoIndex
                    );
                    insertedRangeTotal += unit.rangeAmount;
                    return (unitsNotInsert, insertedRangeTotal);
                } else {
                    uint256 rangeDiff = item.rangeStart - unit.rangeStart;
                    updateRoundLockRangeUnits(
                        RoundLockRangeUnit(
                            unit.rangeStart,
                            item.rangeAmount + rangeDiff
                        ),
                        VRFMachineIndex,
                        VRFIndex,
                        batchInfoIndex,
                        i
                    );
                    insertedRangeTotal += rangeDiff;
                    if (unitRangeEnd <= itemRangeEnd) {
                        if (unit.rangeAmount != rangeDiff) {
                            unit.rangeAmount -= rangeDiff;
                            unit.rangeStart = item.rangeStart;
                            assembly {
                                mstore(
                                    unitsNotInsert,
                                    add(mload(unitsNotInsert), 1)
                                )
                            }
                            unitsNotInsert[unitIndex] = unit;
                            unitIndex++;
                        }
                        return (unitsNotInsert, insertedRangeTotal);
                    } else {
                        unit.rangeAmount -= rangeDiff + item.rangeAmount;
                        unit.rangeStart = item.rangeStart + item.rangeAmount;
                        assembly {
                            mstore(
                                unitsNotInsert,
                                add(mload(unitsNotInsert), 1)
                            )
                        }
                        unitsNotInsert[unitIndex] = RoundLockRangeUnit(
                            item.rangeStart,
                            item.rangeAmount
                        );
                        unitIndex++;
                    }
                }
            } else if (unit.rangeStart <= itemRangeEnd) {
                if (unitRangeEnd <= itemRangeEnd) {
                    assembly {
                        mstore(unitsNotInsert, add(mload(unitsNotInsert), 1))
                    }
                    unitsNotInsert[unitIndex] = unit;
                    unitIndex++;
                    return (unitsNotInsert, insertedRangeTotal);
                } else {
                    assembly {
                        mstore(unitsNotInsert, add(mload(unitsNotInsert), 1))
                    }
                    unitsNotInsert[unitIndex] = RoundLockRangeUnit(
                        unit.rangeStart,
                        itemRangeEnd + 1 - unit.rangeStart
                    );
                    unitIndex++;
                    unit.rangeAmount -= itemRangeEnd + 1 - unit.rangeStart;
                    unit.rangeStart = itemRangeEnd + 1;
                }
            }

            if (i == (info.batchRangesUnitNum - 1) && unit.rangeAmount > 0) {
                if (unit.rangeStart > itemRangeEnd + 1) {
                    insertRoundLockRangeUnits(
                        unit,
                        VRFMachineIndex,
                        VRFIndex,
                        batchInfoIndex
                    );
                } else {
                    item.rangeAmount += unit.rangeAmount;
                    updateRoundLockRangeUnits(
                        item,
                        VRFMachineIndex,
                        VRFIndex,
                        batchInfoIndex,
                        i
                    );
                }
                insertedRangeTotal += unit.rangeAmount;
            }
        }
    }

    function getRoundBatchInfos(uint256 VRFMachineIndex, uint256 VRFIndex)
        public
        view
        returns (RoundLockReservesBatchInfo[] memory)
    {
        RoundLockReservesBatchInfo[]
            memory matches = new RoundLockReservesBatchInfo[](
                roundLockReserveses[VRFMachineIndex][VRFIndex].batchesNum
            );

        for (
            uint256 i = 0;
            i <= roundLockReserveses[VRFMachineIndex][VRFIndex].batchesNum;
            i++
        ) {
            RoundLockReservesBatchInfo memory e = roundLockReserveses[
                VRFMachineIndex
            ][VRFIndex].batchInfos[i];
            matches[i] = e;
        }
        return matches;
    }

    function getRoundBatchDatas(
        uint256 VRFMachineIndex,
        uint256 VRFIndex,
        uint256 batchIndex
    ) public view returns (RoundLockRangeUnit[] memory) {
        RoundLockRangeUnit[] memory matches = new RoundLockRangeUnit[](
            roundLockReserveses[VRFMachineIndex][VRFIndex]
                .batchInfos[batchIndex]
                .batchRangesUnitNum
        );

        for (
            uint256 i = 0;
            i <
            roundLockReserveses[VRFMachineIndex][VRFIndex]
                .batchInfos[batchIndex]
                .batchRangesUnitNum;
            i++
        ) {
            RoundLockRangeUnit memory e = roundLockReserveses[VRFMachineIndex][
                VRFIndex
            ]
                .batchDatas[
                    roundLockReserveses[VRFMachineIndex][VRFIndex]
                        .batchInfos[batchIndex]
                        .dataIndex
                ]
                .RoundLockRangeUnits[i];
            matches[i] = e;
        }
        return matches;
    }

    function sortRoundBatchInfosByAmount(
        RoundLockReservesBatchInfo[] memory items
    ) public pure returns (RoundLockReservesBatchInfo[] memory) {
        for (uint256 i = 1; i < items.length; i++)
            for (uint256 j = 0; j < i; j++)
                if (items[i].batchLockedAmount < items[j].batchLockedAmount) {
                    RoundLockReservesBatchInfo memory x = items[i];
                    items[i] = items[j];
                    items[j] = x;
                }

        return items;
    }

    function sortRoundBatchDataUnitsByRangeStart(
        RoundLockRangeUnit[] memory items
    ) public pure returns (RoundLockRangeUnit[] memory) {
        for (uint256 i = 1; i < items.length; i++)
            for (uint256 j = 0; j < i; j++)
                if (items[i].rangeStart < items[j].rangeStart) {
                    RoundLockRangeUnit memory x = items[i];
                    items[i] = items[j];
                    items[j] = x;
                }

        return items;
    }

    function calcBuyInsurancePayment(
        address PVRFContract,
        uint256 PVRFIndex,
        uint256 prob,
        uint256 valuation,
        bool direction
    )
        public
        view
        returns (
            uint256,
            uint8,
            uint256
        )
    {
        uint256 surplusReserves = totalReserves - totalLockedReserves;
        require(valuation <= surplusReserves, "insurance reserves not enough");
        uint256 a = valuation;
        (PVRFData memory pvrfdata, ) = IPVRF(PVRFContract).getVRFInfo(
            PVRFIndex
        );
        uint256 certain = IPVRF(PVRFContract).VRFRANGE();
        uint256 hour = ceil(
            pvrfdata.expactGenerateTimestamp - block.timestamp,
            3600
        );
        if (direction == false) {
            prob = certain.sub(prob);
        }
        uint256 payment1 = a.mul(prob).div(certain);
        uint256 bignumber = 10000;

        uint256 payment2 = a.mul(a).mul(5).mul(hour);
        payment2 = payment2.div(surplusReserves).div(bignumber);
        uint256 payment3 = a.mul(5).div(bignumber);
        return (payment1 + payment2 + payment3, uint8(hour), surplusReserves);
    }

    function nextResizeReservesVRFIndex() public view returns (uint256) {
        return _nextResizeReservesVRFIndex;
    }

    function resizeReserves() public {
        calcVRFRound();
        if (
            _nextResizeReservesVRFIndex == IPVRF(standardPVRF).getPresentIndex()
        ) return;
        (, uint8 VRFStatus) = IPVRF(standardPVRF).getVRFInfo(
            _nextResizeReservesVRFIndex
        );
        if (VRFStatus != 0) return;

        if (
            outgoingReservesAmountMap[_nextResizeReservesVRFIndex]
                .ITokenAmount > 0
        ) {
            uint256 reservesAmount = (totalReserves *
                outgoingReservesAmountMap[_nextResizeReservesVRFIndex]
                    .ITokenAmount) / IToken(ITokenContract).totalSupply();
            outgoingReservesAmountMap[_nextResizeReservesVRFIndex]
                .amount = reservesAmount;
            IToken(ITokenContract).burn(
                outgoingReservesAmountMap[_nextResizeReservesVRFIndex]
                    .ITokenAmount
            );
            totalReserves -= reservesAmount;

            emit ResizeReserves(
                _nextResizeReservesVRFIndex,
                false,
                reservesAmount,
                outgoingReservesAmountMap[_nextResizeReservesVRFIndex]
                    .ITokenAmount
            );
        }

        if (incomingReservesAmountMap[_nextResizeReservesVRFIndex].amount > 0) {
            uint256 ITokenAmount = (incomingReservesAmountMap[
                _nextResizeReservesVRFIndex
            ].amount * IToken(ITokenContract).totalSupply()) / totalReserves;
            incomingReservesAmountMap[_nextResizeReservesVRFIndex]
                .ITokenAmount = ITokenAmount;
            IToken(ITokenContract).mint(address(this), ITokenAmount);
            totalReserves += incomingReservesAmountMap[
                _nextResizeReservesVRFIndex
            ].amount;

            emit ResizeReserves(
                _nextResizeReservesVRFIndex,
                true,
                incomingReservesAmountMap[_nextResizeReservesVRFIndex].amount,
                ITokenAmount
            );
        }

        _nextResizeReservesVRFIndex == IPVRF(standardPVRF).getPresentIndex();
    }

    function calcVRFRound() public {
        address PVRFContract;
        uint256 nextVRFRound;
        uint256 presentIndex;
        proptoPredictCustomIdGroup memory item;

        for (uint256 i = 1; i <= _PVRFIndexCounter.current(); i++) {
            PVRFContract = PVRFS[i];
            if (PVRFContract == address(0)) {
                continue;
            }
            presentIndex = IPVRF(PVRFContract).getPresentIndex();
            nextVRFRound = nextVRFRounds[i];

            if (nextVRFRound == presentIndex) continue;
            (, uint8 VRFStatus) = IPVRF(PVRFContract).getVRFInfo(nextVRFRound);
            if (VRFStatus != 0) continue;
            for (
                uint256 j = 1;
                j <=
                proptoPredictCustomIdGroupsIndexCounter[i][nextVRFRound]
                    .current();
                j++
            ) {
                item = proptoPredictCustomIdGroups[i][nextVRFRound][j];
                (uint8 PStatus, uint256 VerifiedTokenId) = IProptoPredict(
                    item.proptoPredictContract
                ).CustomIdPredictStatus(
                        item.customId,
                        PVRFContract,
                        nextVRFRound
                    );
                if (PStatus == 1) {
                    for (uint256 k = 0; k < item.indexes.length; k++) {
                        if (
                            VerifiedTokenId ==
                            insuranceDatas[item.indexes[k]].tokenId
                        ) {
                            insuranceDatas[item.indexes[k]].settlement = true;

                            emit ProptoInsuranceSettlement(item.indexes[k]);

                            roundLockReserveses[i][nextVRFRound]
                                .totalSettlementAmount += insuranceDatas[
                                item.indexes[k]
                            ].insuranceAmount;
                        }
                    }

                    for (uint256 k = 0; k < item.reverseIndexes.length; k++) {
                        if (
                            VerifiedTokenId !=
                            insuranceDatas[item.reverseIndexes[k]].tokenId
                        ) {
                            insuranceDatas[item.reverseIndexes[k]]
                                .settlement = true;

                            emit ProptoInsuranceSettlement(
                                item.reverseIndexes[k]
                            );

                            roundLockReserveses[i][nextVRFRound]
                                .totalSettlementAmount += insuranceDatas[
                                item.reverseIndexes[k]
                            ].insuranceAmount;
                        }
                    }
                }
            }

            if (roundLockReserveses[i][nextVRFRound].totalLockedAmount > 0) {
                totalLockedReserves -= roundLockReserveses[i][nextVRFRound]
                    .totalLockedAmount;
            }

            if (
                roundLockReserveses[i][nextVRFRound].totalSettlementAmount > 0
            ) {
                totalSettlementReserves += roundLockReserveses[i][nextVRFRound]
                    .totalSettlementAmount;
                totalReserves -= roundLockReserveses[i][nextVRFRound]
                    .totalSettlementAmount;
            }

            nextVRFRounds[i] = presentIndex;
        }
    }

    function addPVRFWhite(address contractAddress) public onlyOwner {
        uint256 index;
        for (uint256 i = 1; i <= _PVRFIndexCounter.current(); i++) {
            if (PVRFS[i] == contractAddress) {
                index = i;
                break;
            }
        }
        if (index > 0) {
            if (suspendedPVRFS[index] > 0) {
                suspendedPVRFS[index] = 0;
            }
        } else {
            _PVRFIndexCounter.increment();
            index = _PVRFIndexCounter.current();
            PVRFS[index] = contractAddress;
            nextVRFRounds[index] = IPVRF(contractAddress).getPresentIndex();
        }
    }

    function removePVRFWhite(address contractAddress) public onlyOwner {
        uint256 PVRFIndex = getPVRFContractIndex(contractAddress);
        suspendedPVRFS[PVRFIndex] = 1;
    }

    function setStandardPVRF(address contractAddress) public onlyOwner {
        getPVRFContractIndex(contractAddress);
        standardPVRF = contractAddress;
    }

    function getPVRFContractIndex(address contractAddress)
        public
        view
        returns (uint256)
    {
        uint256 index;
        for (uint256 i = 1; i <= _PVRFIndexCounter.current(); i++) {
            if (PVRFS[i] == contractAddress) {
                index = i;
                break;
            }
        }
        require(index > 0, "PVRF not exist");
        require(suspendedPVRFS[index] == 0, "PVRF has been suspended");
        return index;
    }

    function getPVRFS() public view returns (address[] memory) {
        uint256 j = 0;
        for (uint256 i = 1; i <= _PVRFIndexCounter.current(); i++) {
            if (PVRFS[i] != address(0)) {
                j++;
            }
        }
        address[] memory PVRFSAddresses = new address[](j);
        j = 0;
        for (uint256 i = 1; i <= _PVRFIndexCounter.current(); i++) {
            if (PVRFS[i] != address(0)) {
                PVRFSAddresses[j] = PVRFS[i];
                j++;
            }
        }
        return PVRFSAddresses;
    }

    function getInsuranceDataCurrentIndex() public view returns (uint256) {
        return _insuranceDataCounter.current();
    }

    function getInsuranceData(uint256 index)
        public
        view
        returns (insuranceData memory)
    {
        insuranceData memory id = insuranceDatas[index];
        if (id.settlement == true) {
            id.status = ISTATUS_DONESETTLEMENT;
        } else {
            uint8 PStatus = IProptoPredict(id.proptoPredictContract)
                .getPredictStatus(id.tokenId);
            if (PStatus == 0) {
                id.status = ISTATUS_UNDERWRITING;
            } else if (PStatus == 1) {
                id.status = ISTATUS_PROCESSING;
            } else {
                id.status = ISTATUS_EXPIRED;
            }
        }

        return id;
    }

    function collectInsurancePay(uint256 index) public {
        require(insuranceDatas[index].settlement == true, "none settlement");
        require(insuranceDatas[index].collected == false, "already collected");

        insuranceDatas[index].collected = true;
        IERC20(reservesContract).transferFrom(
            address(this),
            insuranceDatas[index].beneficiary,
            insuranceDatas[index].insuranceAmount
        );

        emit ProptoInsuranceSettlementCollect(index);
    }

    function ceil(uint256 a, uint256 m) public pure returns (uint256) {
        return (a + m - 1) / m;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IProptoPredictFactory {
    event ProptoPredictCollectionCreated(
        address indexed creator,
        uint256 index,
        address ProptoPredictContract,
        string name,
        string symbol
    );

    function createNewProptoPredict(string memory name, string memory symbol)
        external
        returns (address);

    function getProptoPredictIndex(address ProptoPredictAddress)
        external
        view
        returns (uint256);

    function getProptoPredictAddress(uint256 index)
        external
        view
        returns (address);

    function validateProptoPredictAddress(address ProptoPredictAddress)
        external
        view
        returns (bool);

    function proptoInsuranceContract() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";

struct ProptoPredictInfo {
    address PVRFContract;
    uint256 PVRFIndex;
    uint256 startRange;
    uint256 amount;
    uint256 customId;
    uint8 status;
}

struct PVRFRoundPrediction {
    uint256 predictKeyNumbers;
    uint256 startRange;
    uint256[] tokenIds;
}

interface IProptoPredict is IERC721Metadata {
    event ProptoPredictCreated(
        address indexed to,
        uint256 tokenId,
        address PVRFContract,
        uint256 PVRFIndex,
        uint256 startRange,
        uint256 amount,
        uint256 customId
    );

    function currentTokenId() external view returns (uint256);

    function safeMint(
        address to,
        ProptoPredictInfo memory ppi,
        string memory uri
    ) external returns (uint256);

    function getCustomIdRoundPredictsInfo(
        uint256 customId,
        address PVRFContract,
        uint256 PVRFIndex
    ) external view returns (PVRFRoundPrediction memory);

    function getLastCustomIdPredict(uint256 customId)
        external
        view
        returns (ProptoPredictInfo memory);

    function getPredictStatus(uint256 tokenId) external view returns (uint8);

    function getInfo(uint256 tokenId)
        external
        view
        returns (ProptoPredictInfo memory);

    function CustomIdPredictStatus(
        uint256 customId,
        address PVRFContract,
        uint256 PVRFIndex
    ) external view returns (uint8 VStatus, uint256 VerifiedTokenId);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct insuranceData {
    address proptoPredictContract;
    uint256 tokenId;
    uint256 customId;
    uint256 insuranceAmount;
    address applicant;
    address beneficiary;
    bool direction;
    bool settlement;
    bool collected;
    uint256 fee;
    uint8 time;
    uint8 status;
}

struct inoutReservesDetail {
    uint256 amount;
    bool collected;
    uint256 PVRFIndex;
    uint256 ITokenAmount;
    bool direction; // true = in , false = out
}

struct inoutReservesDetails {
    uint256 detailNum;
    mapping(uint256 => inoutReservesDetail) list;
}

struct incomingReservesAmount {
    uint256 amount;
    uint256 ITokenAmount;
}

struct outgoingReservesAmount {
    uint256 amount;
    uint256 ITokenAmount;
}

struct proptoPredictCustomIdGroup {
    address proptoPredictContract;
    uint256 customId;
    uint256[] indexes;
    uint256[] reverseIndexes;
}
struct RoundLockRangeUnit {
    uint256 rangeStart;
    uint256 rangeAmount;
}

struct RoundLockReservesBatchInfo {
    uint256 batchRangeTotal;
    uint256 batchLockedAmount;
    uint256 batchLockedMaximum;
    uint256 batchRangesUnitNum;
    uint256 dataIndex;
}

struct RoundLockReservesBatchData {
    mapping(uint256 => RoundLockRangeUnit) RoundLockRangeUnits;
}

struct RoundLockReserves {
    uint256 totalSettlementAmount;
    uint256 totalLockedAmount;
    mapping(uint256 => RoundLockReservesBatchInfo) batchInfos;
    mapping(uint256 => RoundLockReservesBatchData) batchDatas;
    uint256 batchesNum;
}

interface IProptoInsurance {
    event ProptoInsuranceCreated(
        uint256 proptoInsuranceIndex,
        address indexed proptoPredictContract,
        uint256 tokenId,
        uint256 indexed customId,
        uint256 valuation,
        address indexed applicant,
        address beneficiary,
        bool direction,
        bool settlement,
        bool collected,
        uint256 fee,
        uint8 hour
    );

    event ProptoInsuranceSettlement(uint256 proptoInsuranceIndex);

    event ProptoInsuranceSettlementCollect(uint256 proptoInsuranceIndex);

    event InOutReserves(
        address indexed from,
        bool direction,
        uint256 amount,
        uint256 ITokenamount,
        uint256 resizeRoundIndex,
        uint256 walletListIndex
    );

    event ResizeReserves(
        uint256 resizeRoundIndex,
        bool direction,
        uint256 amount,
        uint256 ITokenAmount
    );

    function totalReserves() external view returns (uint256);

    function totalLockedReserves() external view returns (uint256);

    function getITokenValue() external view returns (uint256);

    function getReservesValue() external view returns (uint256);

    function addInsuranceShare(uint256 amount) external;

    function removeInsuranceShare(uint256 amount) external;

    function collectInOutAsset(uint256 ListIndex) external;

    function getInoutReservesCurrentIndex() external view returns (uint256);

    function getInoutReservesDetail(uint256 ListIndex)
        external
        view
        returns (inoutReservesDetail memory);

    function buyInsurance(
        address keyChainContract,
        uint256 tokenId,
        uint256 amount,
        address applicant,
        address beneficiary,
        bool direction
    ) external;

    function calcBuyInsurancePayment(
        address PVRFContract,
        uint256 PVRFIndex,
        uint256 prob,
        uint256 valuation,
        bool direction
    )
        external
        view
        returns (
            uint256,
            uint8,
            uint256
        );

    function collectInsurancePay(uint256 index) external;

    function reservesContract() external view returns (address);

    function getPVRFS() external view returns (address[] memory PVRFSAddresses);

    function nextResizeReservesVRFIndex() external view returns (uint256);

    function getInsuranceDataCurrentIndex() external view returns (uint256);

    function getInsuranceData(uint256 index)
        external
        view
        returns (insuranceData memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct PVRFData {
    uint64 expactGenerateTimestamp;
    uint64 VRF;
    uint256 blocknumber;
    uint256 requestId;
    uint256 randomWord;
    uint8 requestIndex;
}

interface IPVRF {
    event PVRFRequest(
        uint256 indexed startIndex,
        uint32 requestnum,
        address msgsender
    );

    event PVRFGenerated(
        uint256 indexed index,
        uint256 randomWord,
        uint8 requestIndex
    );

    function name() external view returns (string memory);

    function version() external view returns (uint8);

    function intervalSeconds() external view returns (uint256);

    function VRFRANGE() external view returns (uint256);

    function VRFMAX() external view returns (uint256);

    function VRFMIN() external view returns (uint256);

    function lastFulfillIndex() external view returns (uint256);

    function lastRequestIndex() external view returns (uint256);

    function startIndex() external view returns (uint256);

    function getPresentIndex() external view returns (uint256);

    function getVRFInfo(uint256 index)
        external
        view
        returns (PVRFData memory, uint8);

    function getPresentVRFInfo() external view returns (PVRFData memory, uint8);

    function RequestVRFs() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Insurance Providers Token", "IT") {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public virtual override onlyOwner {
        _burn(owner(), amount);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/extensions/IERC721Metadata.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC20.sol";
import "../../../utils/Context.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}