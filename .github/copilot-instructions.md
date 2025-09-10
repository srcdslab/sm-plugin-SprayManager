# SprayManager Plugin - Copilot Coding Instructions

## Project Overview

SprayManager is a comprehensive SourcePawn plugin for SourceMod that manages player sprays on Source engine game servers. It provides advanced spray control features including NSFW content management, spray banning, proximity blocking, and persistent spray systems.

**Key Stats:**
- Main plugin: 1,400+ lines of SourcePawn code
- Modular architecture with 5 specialized modules
- Database-driven with MySQL support (UTF8MB4)
- Multi-language support via SourceMod translations
- Automated CI/CD with GitHub Actions

## Architecture & File Structure

### Core Files
- **`addons/sourcemod/scripting/SprayManager.sp`** - Main plugin file (1,400+ lines)
- **`addons/sourcemod/scripting/include/SprayManager.inc`** - Public API for external plugins
- **`sourceknight.yaml`** - Build configuration for SourceKnight build system

### Modular Components (`addons/sourcemod/scripting/modules/`)
- **`functions.inc`** - Core utility functions and database operations
- **`module_api.inc`** - Native functions and forwards for plugin API
- **`module_commands.inc`** - All command handlers (admin and player commands)
- **`module_cvars.inc`** - ConVar definitions and change handlers
- **`module_menu.inc`** - Admin menu integration

### Supporting Files
- **`migration/300_character_collate_utf8mb4.sql`** - Database migration script
- **`materials/spraymanager/`** - Custom spray materials for NSFW handling
- **`.github/workflows/ci.yml`** - Automated build and release workflow

## Development Environment

### Build System
This project uses **SourceKnight** as the build system, which is primarily used in CI/CD workflows. SourceKnight automatically manages dependencies and compilation.

**Build Configuration**: `sourceknight.yaml` defines:
- SourceMod 1.11.0-git6934 (automatically downloaded)
- MultiColors plugin dependency
- FixSprayExploit plugin dependency
- Build targets and output paths

**Local Development**: The build process is designed for CI environments. For local development, you would need the SourcePawn compiler (spcomp) and the required dependencies manually installed.

**CI Build Process** (via GitHub Actions):
```bash
# Uses maxime1907/action-sourceknight@v1
# Automatically installs dependencies and compiles
# Outputs to .sourceknight/package/addons/sourcemod/plugins/
```

### Dependencies
The plugin requires these dependencies (auto-managed by SourceKnight):
- **SourceMod 1.11.0+** - Core framework
- **MultiColors** - Advanced chat coloring
- **FixSprayExploit** - Security patches for spray exploits

### Database Requirements
- **MySQL/MariaDB** with UTF8MB4 charset support
- Database name: `spraymanager` (configurable in `databases.cfg`)
- Run migration scripts when upgrading from older versions

## Coding Standards & Best Practices

### SourcePawn Conventions
```sourcepawn
#pragma semicolon 1
#pragma newdecls required

// Global variables prefix
ConVar g_cvarEnableSprays = null;
Handle g_hDatabase = null;
bool g_bLoadedLate = false;
int g_iAllowSpray = 0;

// Function naming: PascalCase
public void OnPluginStart()
public bool CheckClientSprayPermission(int client)

// Local variables: camelCase
int clientIndex = 0;
char szQuery[MAX_SQL_QUERY_LENGTH];
```

### Memory Management
```sourcepawn
// ALWAYS use delete directly - no null checks needed
delete g_hSomeHandle;  // ✅ Correct
g_hSomeHandle = null;

// NEVER use .Clear() on StringMap/ArrayList - creates memory leaks
delete g_hStringMap;   // ✅ Correct
g_hStringMap = new StringMap();

// NOT: g_hStringMap.Clear();  // ❌ Memory leak
```

### Native Functions & Forwards
```sourcepawn
// Native function registration
CreateNative("SprayManager_IsClientSprayBanned", Native_IsClientSprayBanned);
CreateNative("SprayManager_BanClientSpray", Native_BanClientSpray);

// Forward creation
g_hForward_OnClientSprayBanned = CreateGlobalForward("SprayManager_OnClientSprayBanned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String);

// Forward calling pattern
stock void Call_OnClientSprayBanned(int admin, int target, int length, const char[] reason)
{
    if (g_hForward_OnClientSprayBanned == null)
        return;
        
    Call_StartForward(g_hForward_OnClientSprayBanned);
    Call_PushCell(admin);
    Call_PushCell(target);
    Call_PushCell(length);
    Call_PushString(reason);
    Call_Finish();
}
```

### Error Handling
```sourcepawn
// Always validate client indices
if (!IsValidClient(client))
    return false;

// Check database connection
if (g_hDatabase == null)
{
    LogError("Database connection is null");
    return;
}

// Handle SQL errors in callbacks
public void SQL_Callback(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("SQL Error: %s", error);
        return;
    }
}
```

### Command Registration Pattern
```sourcepawn
// Console commands (all players)
RegConsoleCmd("sm_marknsfw", Command_MarkNSFW, "Marks your spray as NSFW");
RegConsoleCmd("sm_nsfw", Command_NSFW, "Opt-in or out of seeing NSFW sprays");

// Admin commands with flag requirements
RegAdminCmd("sm_sprayban", Command_SprayBan, ADMFLAG_GENERIC, "Ban a client from spraying");
RegAdminCmd("sm_tracespray", Command_TraceSpray, ADMFLAG_GENERIC, "Finds a spray under your crosshair");

// Command handler pattern
public Action Command_MarkNSFW(int client, int argc)
{
    // Always validate client from console
    if (!client)
    {
        PrintToServer("[SprayManager] Cannot use command from server console.");
        return Plugin_Handled;
    }
    
    // Validate database connection
    if (g_hDatabase == null || !g_bFullyConnected)
    {
        CReplyToCommand(client, "{green}[SprayManager]{default} Unable to update status, please wait a few seconds and try again.");
        return Plugin_Handled;
    }
    
    // Validate client state
    if (!IsValidClient(client))
    {
        ReplyToCommand(client, "[SprayManager] Unable to update status, please wait a few seconds and try again.");
        return Plugin_Handled;
    }
    
    // Command logic here...
    return Plugin_Handled;
}
```

### Database Operations
```sourcepawn
// ALL SQL queries MUST be asynchronous
Database.Query(SQL_Callback, szQuery, GetClientUserId(client));

// ALWAYS escape user input
Database.Escape(szInput, szEscaped, sizeof(szEscaped));

// Use methodmap for database operations
g_hDatabase.Query(SQL_Callback, "SELECT * FROM sprays WHERE steamid = '%s'", szSteamID);
```

## Key Features & Components

### Spray Management System
- **Spray Banning**: Time-based bans with admin controls
- **Hash Banning**: Ban specific spray content regardless of user
- **NSFW Detection**: Automatic and manual NSFW marking with filtering
- **Proximity Blocking**: Prevent overspraying in close proximity

### Database Schema
Tables managed by the plugin:
- `sm_spraymanager_sprays` - Spray metadata and status
- `sm_spraymanager_bans` - Spray ban records
- `sm_spraymanager_hashbans` - Content hash bans

### Configuration (ConVars)
```sourcepawn
sm_spraymanager_enablesprays "1"              // Enable/disable spray system
sm_spraymanager_authorizedflags "b,z"         // Flags that bypass spray restrictions
sm_spraymanager_blockoverspraying "1"         // Prevent proximity overspraying
sm_spraymanager_persistentsprays "1"          // Re-spray when client lifetime expires
sm_spraymanager_maxspraylifetime "2"          // Max lifetime in rounds
sm_decalfrequency "10.0"                      // Spray frequency control
```

### Messaging & Translation System
```sourcepawn
// Load translations in OnPluginStart()
LoadTranslations("common.phrases");

// Use MultiColors for chat messages
CReplyToCommand(client, "{green}[SprayManager]{default} Your spray is already marked as NSFW.");
CPrintToChat(client, "{green}[SprayManager]{default} Spray traced successfully.");

// Console messages for server
PrintToServer("[SprayManager] Cannot use command from server console.");

// Reply to commands (supports both chat and console)
ReplyToCommand(client, "[SprayManager] Unable to update status, please wait a few seconds and try again.");
```

## Common Development Tasks

### Adding New Commands
1. Add command registration in `module_commands.inc`
2. Implement handler function with proper validation
3. Add translation strings if needed
4. Update admin menu if it's an admin command

### Database Schema Changes
1. Create migration script in `migration/` directory
2. Update table creation in `functions.inc`
3. Modify relevant query functions
4. Test with both MySQL and SQLite

### Adding New Features
1. Define new ConVars in `module_cvars.inc`
2. Add core logic to appropriate module
3. Expose via natives in `module_api.inc` if needed
4. Update include file documentation

### Testing Changes
```bash
# Note: This project uses CI/CD for building
# For testing, either:
# 1. Use GitHub Actions workflow to build
# 2. Set up local SourceMod development environment with dependencies
# 3. Deploy compiled .smx to test server
# 4. Test all affected functionality
# 5. Verify database operations work correctly
```

## API Integration

### Forwards Available
```sourcepawn
SprayManager_OnClientSprayBanned(admin, target, length, reason)
SprayManager_OnClientSprayUnbanned(admin, target)
SprayManager_OnClientSprayHashBanned(admin, target, hash)
SprayManager_OnClientSprayHashUnbanned(admin, target, hash)
SprayManager_OnClientSprayMarkedNSFW(admin, target)
SprayManager_OnClientSprayMarkedSFW(admin, target)
```

### Native Functions
See `SprayManager.inc` for full API documentation with parameter descriptions and return values.

## Build & Deployment

### Automated Build Process
The GitHub Actions workflow (`ci.yml`) automatically:
1. Builds the plugin using SourceKnight
2. Packages materials and configurations
3. Creates release artifacts
4. Tags and releases on master/main branch updates

### Manual Build Steps
```bash
# Note: This project is designed for CI/CD environments
# For local development, you need:
# 1. SourcePawn compiler (spcomp)
# 2. SourceMod includes
# 3. Required dependencies (MultiColors, FixSprayExploit)

# With SourceKnight in CI:
# Uses maxime1907/action-sourceknight@v1 GitHub Action
# Output: .sourceknight/package/addons/sourcemod/plugins/SprayManager.smx
```

### Deployment Package Contents
- `addons/sourcemod/plugins/SprayManager.smx` - Compiled plugin
- `addons/sourcemod/scripting/` - Source code
- `materials/spraymanager/` - NSFW replacement materials
- `migration/` - Database update scripts

## Troubleshooting Common Issues

### Compilation Errors
- Ensure all dependencies are installed via SourceKnight
- Check for missing semicolons (required by `#pragma semicolon 1`)
- Verify new variable declarations follow `#pragma newdecls required`

### Database Issues
- Verify MySQL charset is UTF8MB4
- Run migration scripts for version upgrades
- Check database connection in `databases.cfg`

### Performance Considerations
- Avoid expensive operations in frequently called functions (OnGameFrame, etc.)
- Cache results where possible to improve from O(n) to O(1)
- Use timers sparingly and clean them up properly
- Minimize string operations in hot code paths

## Version Control & Releases

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Update version in `SprayManager.sp` plugin info
- Commit messages should clearly describe functional changes
- Releases are automatically created from tags and master/main pushes

## Security Considerations

- All user input must be escaped before database queries
- Validate client indices before operations
- Check permissions for admin commands
- Sanitize file paths and spray content
- Use proper authentication for database connections

This document should provide a coding agent with comprehensive understanding of the SprayManager plugin architecture, development practices, and common workflows for efficient contribution to the project.