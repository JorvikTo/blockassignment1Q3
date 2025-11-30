#!/bin/bash

# Remix Test Framework Verification Script
# This script verifies the Remix test implementation without requiring compilation

echo "========================================"
echo "Remix Test Framework Verification"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if test files exist
echo "1. Checking test file structure..."
echo ""

files=(
    "test/remix/Assert.sol"
    "test/remix/GovernanceTokenRemixTest.sol"
    "test/remix/DecentralizedTreasuryRemixTest.sol"
    "test/remix/TreasurySystemRemixTest.sol"
    "test/RemixTests.test.js"
)

all_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} Found: $file"
    else
        echo -e "${RED}✗${NC} Missing: $file"
        all_exist=false
    fi
done
echo ""

# Check Assert library functions
echo "2. Verifying Assert library..."
echo ""

assert_functions=(
    "function ok("
    "function equal(uint256"
    "function equal(int256"
    "function equal(bool"
    "function equal(address"
    "function equal(bytes32"
    "function equal(string"
    "function notEqual("
    "function greaterThan("
    "function lessThan("
)

assert_file="test/remix/Assert.sol"
assert_complete=true

if [ -f "$assert_file" ]; then
    for func in "${assert_functions[@]}"; do
        if grep -q "$func" "$assert_file"; then
            echo -e "${GREEN}✓${NC} Found: $func"
        else
            echo -e "${RED}✗${NC} Missing: $func"
            assert_complete=false
        fi
    done
else
    echo -e "${RED}✗${NC} Assert.sol not found"
    assert_complete=false
fi
echo ""

# Count test functions
echo "3. Counting test functions..."
echo ""

count_tests() {
    local file=$1
    local name=$2
    if [ -f "$file" ]; then
        # Count functions that start with 'check' or 'test'
        local count=$(grep -c "function check\|function test" "$file" || echo "0")
        echo -e "${GREEN}✓${NC} $name: $count test functions"
        return $count
    else
        echo -e "${RED}✗${NC} $name: File not found"
        return 0
    fi
}

gov_count=$(count_tests "test/remix/GovernanceTokenRemixTest.sol" "GovernanceToken")
treasury_count=$(count_tests "test/remix/DecentralizedTreasuryRemixTest.sol" "Treasury")
system_count=$(count_tests "test/remix/TreasurySystemRemixTest.sol" "System")

total_tests=$((gov_count + treasury_count + system_count))
echo -e "${YELLOW}Total test functions: $total_tests${NC}"
echo ""

# Check for beforeAll functions
echo "4. Verifying test setup..."
echo ""

for test_file in "test/remix/GovernanceTokenRemixTest.sol" "test/remix/DecentralizedTreasuryRemixTest.sol" "test/remix/TreasurySystemRemixTest.sol"; do
    if [ -f "$test_file" ]; then
        if grep -q "function beforeAll()" "$test_file"; then
            echo -e "${GREEN}✓${NC} $(basename $test_file): Has beforeAll() setup"
        else
            echo -e "${YELLOW}!${NC} $(basename $test_file): No beforeAll() setup"
        fi
    fi
done
echo ""

# Check import statements
echo "5. Checking import statements..."
echo ""

for test_file in "test/remix/GovernanceTokenRemixTest.sol" "test/remix/DecentralizedTreasuryRemixTest.sol" "test/remix/TreasurySystemRemixTest.sol"; do
    if [ -f "$test_file" ]; then
        if grep -q 'import "./Assert.sol"' "$test_file"; then
            echo -e "${GREEN}✓${NC} $(basename $test_file): Imports Assert.sol"
        else
            echo -e "${RED}✗${NC} $(basename $test_file): Missing Assert import"
        fi
    fi
done
echo ""

# Check package.json scripts
echo "6. Verifying npm scripts..."
echo ""

if [ -f "package.json" ]; then
    if grep -q '"test:remix"' package.json; then
        echo -e "${GREEN}✓${NC} Found: npm run test:remix script"
    else
        echo -e "${RED}✗${NC} Missing: npm run test:remix script"
    fi
    
    if grep -q '"test:all"' package.json; then
        echo -e "${GREEN}✓${NC} Found: npm run test:all script"
    else
        echo -e "${YELLOW}!${NC} Missing: npm run test:all script (optional)"
    fi
else
    echo -e "${RED}✗${NC} package.json not found"
fi
echo ""

# Check documentation
echo "7. Checking documentation..."
echo ""

docs=(
    "REMIX_TESTS.md"
    "REMIX_QUICKSTART.md"
    "TEST_IMPLEMENTATION_SUMMARY.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}✓${NC} Found: $doc"
    else
        echo -e "${RED}✗${NC} Missing: $doc"
    fi
done
echo ""

# Summary
echo "========================================"
echo "Verification Summary"
echo "========================================"
echo ""

if $all_exist && $assert_complete; then
    echo -e "${GREEN}✓ All required files present${NC}"
    echo -e "${GREEN}✓ Assert library complete${NC}"
    echo -e "${YELLOW}⚠ Total test functions found: $total_tests${NC}"
    echo ""
    echo "Status: ${GREEN}READY FOR TESTING${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run: npm install"
    echo "2. Run: npm run test:remix"
else
    echo -e "${RED}✗ Some verification checks failed${NC}"
    echo ""
    echo "Status: ${RED}NEEDS ATTENTION${NC}"
fi
echo ""
echo "========================================"
