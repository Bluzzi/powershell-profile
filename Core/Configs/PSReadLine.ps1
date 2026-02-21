# Prevents duplicates from being saved in the command history.
Set-PSReadLineOption -HistoryNoDuplicates

# Automatically moves the cursor to the end of the command line when searching through the command history.
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# Saves commands to the command history incrementally, as they are executed, rather than all at once at the end of the session.
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally

# Sets the maximum size of the command history to 10000 entries (the default is 4096). 
# If the history exceeds this limit, older entries will be removed to make room for new entries.
Set-PSReadLineOption -MaximumHistoryCount 10000

# Use the arrow key (up/down) to navigate through the history.
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

# Use the tab key to open the auto complete menu.
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Use by default the history list view
Set-PSReadLineOption -PredictionViewStyle ListView