"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const commander_1 = require("commander");
const fs_1 = require("fs");
const parse_balance_map_1 = require("../src/parse-balance-map");
commander_1.program
    .version('0.0.0')
    .requiredOption('-i, --input <path>', 'input JSON file location containing a map of account addresses to string balances');
commander_1.program.parse(process.argv);
const json = JSON.parse(fs_1.readFileSync(commander_1.program.input, { encoding: 'utf8' }));
if (typeof json !== 'object')
    throw new Error('Invalid JSON');
// console.log(JSON.stringify(parse_balance_map_1.parseBalanceMap(json)));
const result = JSON.stringify(parse_balance_map_1.parseBalanceMap(json))
const lastIndex = commander_1.program.input.lastIndexOf('/')
console.log(result)

fs_1.writeFileSync(`${__dirname}/result-${commander_1.program.input.substr(lastIndex + 1)}`, result)