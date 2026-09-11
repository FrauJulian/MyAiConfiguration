# Azure DevOps & Microsoft Teams Guidelines

## Core Rule

* READ operations may be performed autonomously.
* WRITE operations always require explicit user confirmation beforehand.
* Treat all remote data as read-only by default.
* Never perform a WRITE operation without asking first.
* Previous approval does not automatically authorize future WRITE operations.
* If the intended WRITE changes materially after approval, ask again.

## READ Operations

READ operations may be performed without confirmation.

Examples:

* Read work items
* Read descriptions
* Read comments
* Read pull requests
* Read pipeline status
* Read repository metadata
* Read Teams messages
* Read conversations and threads
* Read meeting information
* Search Azure DevOps
* Search Microsoft Teams
* Inspect statuses, assignments, tags, fields and history
* Analyze retrieved information

Do not ask for permission before READ operations when they are useful for completing the task.

## WRITE Operations

Before every WRITE operation:

* Explain exactly what will be changed.
* Show the intended content when applicable.
* Ask for explicit confirmation.
* Perform the WRITE only after confirmation.
* Do not assume approval from context or previous actions.

WRITE operations include any action that changes remote state.

## Azure DevOps WRITE Operations

Always ask before:

* Creating work items
* Editing work items
* Editing titles
* Editing descriptions
* Editing acceptance criteria
* Adding comments
* Replying to comments
* Editing or deleting comments
* Changing status or state
* Opening or reopening work items
* Resolving or closing work items
* Assigning or reassigning work items
* Changing priority, severity, tags, iteration or area
* Modifying links or relations
* Creating or modifying pull requests
* Approving or voting on pull requests
* Completing, merging or abandoning pull requests
* Triggering, retrying or cancelling pipelines
* Modifying pipeline configuration
* Creating or deleting branches
* Modifying repository settings
* Modifying policies, releases, environments or deployments
* Any other operation that changes Azure DevOps data

## Microsoft Teams WRITE Operations

Always ask before:

* Sending messages
* Replying to messages
* Editing messages
* Deleting messages
* Reacting to messages
* Creating posts or announcements
* Creating chats or threads
* Creating or modifying channels
* Creating or modifying meetings
* Adding or removing participants
* Changing memberships
* Changing permissions
* Modifying Teams settings
* Any other operation that changes Microsoft Teams data

## Important Restrictions

* Never edit descriptions autonomously.
* Never reply to comments autonomously.
* Never send Teams messages autonomously.
* Never open, close, resolve or reopen items autonomously.
* Never change statuses autonomously.
* Never trigger pipelines autonomously.
* Never approve or merge pull requests autonomously.
* Never perform destructive actions autonomously.

## Autonomous Agent Rule

The agent may freely:

* read
* search
* inspect
* analyze
* summarize

The agent must ask first before it:

* creates
* edits
* deletes
* sends
* comments
* replies
* reacts
* assigns
* changes state
* opens
* closes
* approves
* merges
* triggers
* cancels
* modifies any remote data

When uncertain whether an operation is READ or WRITE, treat it as WRITE and ask first.
