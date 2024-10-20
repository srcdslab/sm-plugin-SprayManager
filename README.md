## Description

This plugin provides functionalities to manage and control player sprays on the server. It includes features such as enabling/disabling sprays, setting spray limits, and more.

## Installation

> [!IMPORTANT]
> For previous users, the version **`2.2.13`** introduce MySQL update to force usage of `utf8mb4`
> You need to perform manual queries if you used SprayManager old database character. (See [Manual database update](#manual-database-update))

To install SprayManager, follow these steps:

1. Download the latest release file.
2. Extract files and move these files into server's according directory.
3. If using MySQL: Create a database for `spraymanager`
4. Update your database config (sourcemod/configs/database.cfg) to include `spraymanager`
4. Restart your server or change the map to load the new plugin.

## Usage

Once installed, you can use the following commands to manage sprays:

### Player Commands
- sm_marknsfw (Usage: `sm_marknsfw`) - Marks your spray as NSFW.
- sm_marksfw (Usage: `sm_marksfw`) - Marks your spray as SFW.
- sm_nsfw (Usage: `sm_nsfw`) - Opt-in or out of seeing NSFW sprays.
- sm_hs (Usage: `sm_hs <target>`) - Hides a player's spray.
- sm_us (Usage: `sm_us <target>`) - Unhides a player's spray.

### Admin Commands
- sm_spray (Usage: `sm_spray <target>`) - Spray a client's spray.
- sm_sprayban (Usage: `sm_sprayban <target> <time> <reason (optional)>`) - Ban a client from spraying.
- sm_sprayunban (Usage: `sm_sprayunban <target>`) - Unban a client and allow them to spray.
- sm_banspray (Usage: `sm_banspray <target>`) - Ban a client's spray from being sprayed (Note: This will not spray-ban the client, it will only ban the spray which they are currently using).
- sm_unbanspray (Usage: `sm_unbanspray <target>`) - Unban a client's spray (Note: This will not spray-unban the client, it will only unban the spray which they are currently using).
- sm_tracespray (Usage: `sm_tracespray`) - Finds a spray under your crosshair.
- sm_removespray (Usage: `sm_removespray`) - Finds and removes a spray under your crosshair.
- sm_forcensfw (Usage: `sm_forcensfw <target>`) - Forces a spray to be marked NSFW.
- sm_forcesfw (Usage: `sm_forcesfw <target>`) - Forces a spray to be marked SFW.
- sm_spraymanagerupdatedb (Usage: `sm_spraymanagerupdatedb`) - Updates all clients info.
- sm_spraymanagerrefreshdb (Usage: `sm_spraymanagerrefreshdb`) - Updates all clients info.
- sm_spraymanagerreloaddb (Usage: `sm_spraymanagerreloaddb`) - Updates all clients info.

## Configuration (cvars)

You can configure SprayManager by editing the configuration file located at `cfg/sourcemod/SprayManager.cfg`. The following options are available:

- `sm_decalfrequency`: Controls how often clients can spray
- `sm_spraymanager_enablesprays`: Set to `1` to enable sprays, `0` to disable
- `sm_spraymanager_authorizedflags`: Authorizes specific flags to spray when usage is disabled server side (See SM wiki for flags)
- `sm_spraymanager_blockoverspraying`: Set to `1` to blocks people from overspraying each other, `0` to disable
- `sm_spraymanager_sendspraystoconnectingclients`: Set to `1` to try to send active sprays to connecting clients, `0` to disable
- `sm_spraymanager_persistentsprays`: Set to `1` to re-spray sprays when their client-sided lifetime (in rounds) expires, `0` to disable
- `sm_spraymanager_maxspraylifetime`: If not using persistent sprays, remove sprays after their global lifetime (in rounds) exceeds this number

## Manual database update

In 2.2.13 we introduced utf8mb4 as standard, you will need to run these queries:

**You need to replace `MY_DATABASE_NAME` with .. your database name (see database.cfg)**
1. Update the global database
```sql
ALTER DATABASE MY_DATABASE_NAME CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
```

2. Update all tables in one query
```sql
-- Update spraymanager table
ALTER TABLE `spraymanager` 
CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Update sprayblacklist table
ALTER TABLE `sprayblacklist` 
CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Update spraynsfwlist table
ALTER TABLE `spraynsfwlist` 
CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```