"use strict";
let __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function (t) {
        for (let s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (let p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseBalanceMap = void 0;
const ethers_1 = require("ethers");
const balance_tree_1 = require("./balance-tree");
const isAddress = ethers_1.utils.isAddress, getAddress = ethers_1.utils.getAddress;
function parseBalanceMap(balances) {
    // if balances are in an old format, process them
    const balancesInNewFormat = Array.isArray(balances)
        ? balances
        : Object.keys(balances).map(function (account) {
            return ({
                address: account,
                earnings: "0x" + balances[account].toString(16),
                reasons: '',
            });
        });
    const dataByAddress = balancesInNewFormat.reduce(function (memo, _a) {
        const account = _a.address, earnings = _a.earnings, reasons = _a.reasons;
        if (!isAddress(account)) {
            throw new Error("Found invalid address: " + account);
        }
        const parsed = getAddress(account);
        if (memo[parsed])
            throw new Error("Duplicate address: " + parsed);
        const parsedNum = ethers_1.BigNumber.from(earnings);
        if (parsedNum.lte(0))
            throw new Error("Invalid amount for account: " + account);
        const flags = {
            isSOCKS: reasons.includes('socks'),
            isLP: reasons.includes('lp'),
            isUser: reasons.includes('user'),
        };
        memo[parsed] = __assign({ amount: parsedNum }, (reasons === '' ? {} : { flags: flags }));
        return memo;
    }, {});
    const sortedAddresses = Object.keys(dataByAddress).sort();
    // construct a tree
    const tree = new balance_tree_1.default(sortedAddresses.map(function (address) { return ({ account: address, amount: dataByAddress[address].amount }); }));
    // generate claims
    const claims = sortedAddresses.reduce(function (memo, address, index) {
        const _a = dataByAddress[address], amount = _a.amount, flags = _a.flags;
        memo[address] = __assign({ index: index, amount: amount.toHexString(), proof: tree.getProof(index, address, amount) }, (flags ? { flags: flags } : {}));
        return memo;
    }, {});
    const tokenTotal = sortedAddresses.reduce(function (memo, key) { return memo.add(dataByAddress[key].amount); }, ethers_1.BigNumber.from(0));
    return {
        merkleRoot: tree.getHexRoot(),
        tokenTotal: tokenTotal.toHexString(),
        claims: claims,
    };
}
exports.parseBalanceMap = parseBalanceMap;
