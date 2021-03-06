module.exports = async ({ deployments, getNamedAccounts }) => {
    const { log, execute } = deployments;
    const { deployer, admin } = await getNamedAccounts();
    const { addGrants } = require("../scripts/addGrants")

    log(`8) Create Grants`)
    // Set start time for grants at now + 48 hours
    // const delay = 48 * 60 * 60
    // const startTime = parseInt(Date.now() / 1000) + delay
    // Create grants from file
    await addGrants(0)
    log(`- Done creating grants`)
    // Change vesting owner
    log(`- Changing vesting contract owner to admin address: ${admin}`)
    await execute('Vesting', {from: deployer }, 'changeOwner', admin);
};

module.exports.skip = async function({ deployments }) {
    const { log, read } = deployments
    const { readGrantsFromFile } = require("../scripts/readGrantsFromFile")
    const grants = readGrantsFromFile()
    if (grants.length > 0) {
        for (const grant of grants) {
            const activeGrant = await read("Vesting", "getTokenGrant", grant.recipient)
            if (activeGrant && activeGrant.amount && activeGrant.amount.gt(0)) {
                log(`8) Create Grants`)
                log(`- Skipping step, grants already created`)
                return true
            }
        }
        return false
    } else {
        log(`8) Create Grants`)
        log(`- Skipping step, could not find grants`)
        return true
    }
}

module.exports.tags = ["8", "CreateGrants"]
module.exports.dependencies = ["7"]