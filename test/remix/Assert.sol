// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Assert
 * @dev Remix-compatible assertion library for Solidity 0.8.20
 * Provides assertion functions for unit testing smart contracts
 */
library Assert {
    event AssertionEvent(
        bool passed,
        string message,
        string methodName
    );

    event AssertionEventUint(
        bool passed,
        string message,
        string methodName,
        uint256 returned,
        uint256 expected
    );

    event AssertionEventInt(
        bool passed,
        string message,
        string methodName,
        int256 returned,
        int256 expected
    );

    event AssertionEventBool(
        bool passed,
        string message,
        string methodName,
        bool returned,
        bool expected
    );

    event AssertionEventAddress(
        bool passed,
        string message,
        string methodName,
        address returned,
        address expected
    );

    event AssertionEventBytes32(
        bool passed,
        string message,
        string methodName,
        bytes32 returned,
        bytes32 expected
    );

    event AssertionEventString(
        bool passed,
        string message,
        string methodName,
        string returned,
        string expected
    );

    function ok(bool a, string memory message) public returns (bool result) {
        result = a;
        emit AssertionEvent(result, message, "ok");
    }

    function equal(uint256 a, uint256 b, string memory message) public returns (bool result) {
        result = (a == b);
        emit AssertionEventUint(result, message, "equal", a, b);
    }

    function equal(int256 a, int256 b, string memory message) public returns (bool result) {
        result = (a == b);
        emit AssertionEventInt(result, message, "equal", a, b);
    }

    function equal(bool a, bool b, string memory message) public returns (bool result) {
        result = (a == b);
        emit AssertionEventBool(result, message, "equal", a, b);
    }

    function equal(address a, address b, string memory message) public returns (bool result) {
        result = (a == b);
        emit AssertionEventAddress(result, message, "equal", a, b);
    }

    function equal(bytes32 a, bytes32 b, string memory message) public returns (bool result) {
        result = (a == b);
        emit AssertionEventBytes32(result, message, "equal", a, b);
    }

    function equal(string memory a, string memory b, string memory message) public returns (bool result) {
        result = (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
        emit AssertionEventString(result, message, "equal", a, b);
    }

    function notEqual(uint256 a, uint256 b, string memory message) public returns (bool result) {
        result = (a != b);
        emit AssertionEventUint(result, message, "notEqual", a, b);
    }

    function notEqual(int256 a, int256 b, string memory message) public returns (bool result) {
        result = (a != b);
        emit AssertionEventInt(result, message, "notEqual", a, b);
    }

    function notEqual(bool a, bool b, string memory message) public returns (bool result) {
        result = (a != b);
        emit AssertionEventBool(result, message, "notEqual", a, b);
    }

    function notEqual(address a, address b, string memory message) public returns (bool result) {
        result = (a != b);
        emit AssertionEventAddress(result, message, "notEqual", a, b);
    }

    function notEqual(bytes32 a, bytes32 b, string memory message) public returns (bool result) {
        result = (a != b);
        emit AssertionEventBytes32(result, message, "notEqual", a, b);
    }

    function notEqual(string memory a, string memory b, string memory message) public returns (bool result) {
        result = (keccak256(abi.encodePacked(a)) != keccak256(abi.encodePacked(b)));
        emit AssertionEventString(result, message, "notEqual", a, b);
    }

    function greaterThan(uint256 a, uint256 b, string memory message) public returns (bool result) {
        result = (a > b);
        emit AssertionEventUint(result, message, "greaterThan", a, b);
    }

    function greaterThan(int256 a, int256 b, string memory message) public returns (bool result) {
        result = (a > b);
        emit AssertionEventInt(result, message, "greaterThan", a, b);
    }

    function lessThan(uint256 a, uint256 b, string memory message) public returns (bool result) {
        result = (a < b);
        emit AssertionEventUint(result, message, "lessThan", a, b);
    }

    function lessThan(int256 a, int256 b, string memory message) public returns (bool result) {
        result = (a < b);
        emit AssertionEventInt(result, message, "lessThan", a, b);
    }
    
    // Backward compatibility aliases
    function lesserThan(uint256 a, uint256 b, string memory message) public returns (bool result) {
        return lessThan(a, b, message);
    }

    function lesserThan(int256 a, int256 b, string memory message) public returns (bool result) {
        return lessThan(a, b, message);
    }
}
