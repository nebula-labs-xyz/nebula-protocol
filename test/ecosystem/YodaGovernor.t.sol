// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BasicDeploy.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract YodaGovernorTest is BasicDeploy {
    function setUp() public {
        deployComplete();
        assertEq(tokenInstance.totalSupply(), 0);
        // this is the TGE
        vm.prank(guardian);
        tokenInstance.initializeTGE(
            address(ecoInstance),
            address(treasuryInstance)
        );
        uint256 ecoBal = tokenInstance.balanceOf(address(ecoInstance));
        uint256 treasuryBal = tokenInstance.balanceOf(
            address(treasuryInstance)
        );

        assertEq(ecoBal, 22_000_000 ether);
        assertEq(treasuryBal, 28_000_000 ether);
        assertEq(tokenInstance.totalSupply(), ecoBal + treasuryBal);

        vm.prank(guardian);
        ecoInstance.grantRole(MANAGER_ROLE, managerAdmin);
        assertEq(govInstance.uupsVersion(), 1);
    }

    function test_Revert_Initialization() public {
        bytes memory expError = abi.encodeWithSignature(
            "InvalidInitialization()"
        );
        vm.prank(guardian);
        vm.expectRevert(expError); // contract already initialized
        govInstance.initialize(tokenInstance, timelockInstance, guardian);
    }

    function test_Owner() public {
        assertTrue(govInstance.owner() == guardian);
    }

    function test_CreateProposal() public {
        // get enough gov tokens to make proposal (20K)
        vm.deal(alice, 1 ether);
        address[] memory winners = new address[](1);
        winners[0] = alice;
        vm.prank(managerAdmin);
        ecoInstance.airdrop(winners, 20001 ether);
        assertEq(tokenInstance.balanceOf(alice), 20001 ether);

        vm.prank(alice);
        tokenInstance.delegate(alice);

        vm.roll(365 days);
        uint256 votes = govInstance.getVotes(alice, block.timestamp - 1 days);
        assertEq(votes, 20001 ether);

        //create proposal
        bytes memory callData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            managerAdmin,
            1 ether
        );
        address[] memory to = new address[](1);
        to[0] = address(tokenInstance);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        vm.prank(alice);
        uint256 proposalId = govInstance.propose(
            to,
            values,
            calldatas,
            "Proposal #1: send 1 token to managerAdmin"
        );

        vm.roll(365 days + 7201);
        IGovernor.ProposalState state = govInstance.state(proposalId);
        assertTrue(state == IGovernor.ProposalState.Active); //proposal active
    }

    function test_CastVote() public {
        // get enough gov tokens to make proposal (20K)
        // vm.deal(alice, 1 ether);
        address[] memory winners = new address[](3);
        winners[0] = alice;
        winners[1] = bob;
        winners[2] = charlie;
        vm.prank(managerAdmin);
        ecoInstance.airdrop(winners, 200_000 ether);
        assertEq(tokenInstance.balanceOf(alice), 200_000 ether);

        vm.prank(alice);
        tokenInstance.delegate(alice);
        vm.prank(bob);
        tokenInstance.delegate(bob);
        vm.prank(charlie);
        tokenInstance.delegate(charlie);

        vm.roll(365 days);
        uint256 votes = govInstance.getVotes(alice, block.timestamp - 1 days);
        assertEq(votes, 200_000 ether);

        //create proposal
        bytes memory callData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            managerAdmin,
            1 ether
        );
        address[] memory to = new address[](1);
        to[0] = address(tokenInstance);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        vm.prank(alice);
        uint256 proposalId = govInstance.propose(
            to,
            values,
            calldatas,
            "Proposal #1: send 1 token to managerAdmin"
        );

        vm.roll(365 days + 7201);
        IGovernor.ProposalState state = govInstance.state(proposalId);
        assertTrue(state == IGovernor.ProposalState.Active); //proposal active

        vm.prank(alice);
        govInstance.castVote(proposalId, 1);
        vm.prank(bob);
        govInstance.castVote(proposalId, 1);
        vm.prank(charlie);
        govInstance.castVote(proposalId, 1);

        vm.roll(365 days + 7201 + 50401);

        // (uint256 against, uint256 forvotes, uint256 abstain) = govInstance
        //     .proposalVotes(proposalId);
        // console.log(against, forvotes, abstain);
        IGovernor.ProposalState state1 = govInstance.state(proposalId);
        assertTrue(state1 == IGovernor.ProposalState.Succeeded); //proposal succeeded
    }

    function test_QueProposal() public {
        // get enough gov tokens to make proposal (20K)
        address[] memory winners = new address[](3);
        winners[0] = alice;
        winners[1] = bob;
        winners[2] = charlie;
        vm.prank(managerAdmin);
        ecoInstance.airdrop(winners, 200_000 ether);
        assertEq(tokenInstance.balanceOf(alice), 200_000 ether);

        vm.prank(alice);
        tokenInstance.delegate(alice);
        vm.prank(bob);
        tokenInstance.delegate(bob);
        vm.prank(charlie);
        tokenInstance.delegate(charlie);

        vm.roll(365 days);
        uint256 votes = govInstance.getVotes(alice, block.timestamp - 1 days);
        assertEq(votes, 200_000 ether);

        //create proposal
        bytes memory callData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            managerAdmin,
            1 ether
        );
        address[] memory to = new address[](1);
        to[0] = address(tokenInstance);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        vm.prank(alice);
        uint256 proposalId = govInstance.propose(
            to,
            values,
            calldatas,
            "Proposal #1: send 1 token to managerAdmin"
        );

        vm.roll(365 days + 7200 + 1);
        IGovernor.ProposalState state1 = govInstance.state(proposalId);
        assertTrue(state1 == IGovernor.ProposalState.Active); //proposal active

        vm.prank(alice);
        govInstance.castVote(proposalId, 1);
        vm.prank(bob);
        govInstance.castVote(proposalId, 1);
        vm.prank(charlie);
        govInstance.castVote(proposalId, 1);

        vm.roll(365 days + 7200 + 50400 + 1);

        IGovernor.ProposalState state2 = govInstance.state(proposalId);
        assertTrue(state2 == IGovernor.ProposalState.Succeeded); //proposal succeded

        bytes32 descHash = keccak256(
            abi.encodePacked("Proposal #1: send 1 token to managerAdmin")
        );
        uint256 proposalId2 = govInstance.hashProposal(
            to,
            values,
            calldatas,
            descHash
        );

        assertEq(proposalId, proposalId2);

        govInstance.queue(to, values, calldatas, descHash);
        IGovernor.ProposalState state3 = govInstance.state(proposalId);
        assertTrue(state3 == IGovernor.ProposalState.Queued); //proposal queued
    }

    function test_ExecuteProposal() public {
        // get enough gov tokens to meet the quorum requirement (500K)
        address[] memory winners = new address[](3);
        winners[0] = alice;
        winners[1] = bob;
        winners[2] = charlie;
        vm.prank(managerAdmin);
        ecoInstance.airdrop(winners, 200_000 ether);
        assertEq(tokenInstance.balanceOf(alice), 200_000 ether);

        vm.prank(alice);
        tokenInstance.delegate(alice);
        vm.prank(bob);
        tokenInstance.delegate(bob);
        vm.prank(charlie);
        tokenInstance.delegate(charlie);

        vm.roll(365 days);
        uint256 votes = govInstance.getVotes(alice, block.timestamp - 1 days);
        assertEq(votes, 200_000 ether);

        //create proposal
        bytes memory callData = abi.encodeWithSignature(
            "release(address,address,uint256)",
            address(tokenInstance),
            managerAdmin,
            1 ether
        );

        address[] memory to = new address[](1);
        to[0] = address(treasuryInstance);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        vm.prank(alice);
        uint256 proposalId = govInstance.propose(
            to,
            values,
            calldatas,
            "Proposal #1: send 1 token to managerAdmin"
        );

        vm.roll(365 days + 7200 + 1);
        IGovernor.ProposalState state1 = govInstance.state(proposalId);
        assertTrue(state1 == IGovernor.ProposalState.Active); //proposal active

        vm.prank(alice);
        govInstance.castVote(proposalId, 1);
        vm.prank(bob);
        govInstance.castVote(proposalId, 1);
        vm.prank(charlie);
        govInstance.castVote(proposalId, 1);

        vm.roll(365 days + 7200 + 50400 + 1);

        IGovernor.ProposalState state4 = govInstance.state(proposalId);
        assertTrue(state4 == IGovernor.ProposalState.Succeeded); //proposal succeded

        bytes32 descHash = keccak256(
            abi.encodePacked("Proposal #1: send 1 token to managerAdmin")
        );
        uint256 proposalId2 = govInstance.hashProposal(
            to,
            values,
            calldatas,
            descHash
        );
        assertEq(proposalId, proposalId2);

        govInstance.queue(to, values, calldatas, descHash);

        IGovernor.ProposalState state5 = govInstance.state(proposalId);
        assertTrue(state5 == IGovernor.ProposalState.Queued); //proposal queued

        uint256 eta = govInstance.proposalEta(proposalId);
        vm.warp(eta + 1);
        vm.roll(eta + 1);
        govInstance.execute(to, values, calldatas, descHash);
        IGovernor.ProposalState state7 = govInstance.state(proposalId);

        assertTrue(state7 == IGovernor.ProposalState.Executed); //proposal executed
        assertEq(tokenInstance.balanceOf(managerAdmin), 1 ether);
        assertEq(
            tokenInstance.balanceOf(address(treasuryInstance)),
            28_000_000 ether - 1 ether
        );
    }

    function test_Propose_QuorumDefeat() public {
        // quorum at 1% is 500_000
        address[] memory winners = new address[](3);
        winners[0] = alice;
        winners[1] = bob;
        winners[2] = charlie;
        vm.prank(managerAdmin);
        ecoInstance.airdrop(winners, 30_000 ether);
        assertEq(tokenInstance.balanceOf(alice), 30_000 ether);

        vm.prank(alice);
        tokenInstance.delegate(alice);
        vm.prank(bob);
        tokenInstance.delegate(bob);
        vm.prank(charlie);
        tokenInstance.delegate(charlie);

        vm.roll(365 days);
        uint256 votes = govInstance.getVotes(alice, block.timestamp - 1 days);
        assertEq(votes, 30_000 ether);

        //create proposal
        bytes memory callData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            managerAdmin,
            1 ether
        );
        address[] memory to = new address[](1);
        to[0] = address(tokenInstance);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        vm.prank(alice);
        uint256 proposalId = govInstance.propose(
            to,
            values,
            calldatas,
            "Proposal #1: send 1 token to managerAdmin"
        );

        vm.roll(365 days + 7201);
        IGovernor.ProposalState state = govInstance.state(proposalId);
        assertTrue(state == IGovernor.ProposalState.Active); //proposal active

        vm.prank(alice);
        govInstance.castVote(proposalId, 1);
        vm.prank(bob);
        govInstance.castVote(proposalId, 1);
        vm.prank(charlie);
        govInstance.castVote(proposalId, 1);

        vm.roll(365 days + 7201 + 50400);

        IGovernor.ProposalState state1 = govInstance.state(proposalId);
        assertTrue(state1 == IGovernor.ProposalState.Defeated); //proposal defeated
    }

    function test_Revert_CreateProposal_Branch1() public {
        bytes memory callData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            managerAdmin,
            1 ether
        );
        address[] memory to = new address[](1);
        to[0] = address(tokenInstance);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        bytes memory expError = abi.encodeWithSignature(
            "GovernorInsufficientProposerVotes(address,uint256,uint256)",
            managerAdmin,
            0,
            20000 ether
        );
        vm.prank(managerAdmin);
        vm.expectRevert(expError);
        govInstance.propose(
            to,
            values,
            calldatas,
            "Proposal #1: send 1 token to managerAdmin"
        );
    }
}
