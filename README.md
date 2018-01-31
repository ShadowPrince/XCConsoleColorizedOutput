![ColorizedConsoleOutput](https://github.com/ShadowPrince/XCConsoleColorizedOutput/blob/master/cch.png?raw=true)

## Builing and installation

1. Add desired compatibility UUID to the plist
1. Build the project
1. `xcplugin` is now in the `Developer/Plug-Ins`

## Usage

Plugin loads `~/.xccolors.json` on startup and each subsequent edit. The structure is a json dictionary, with patterns as keys and options as values. 
Value is a `backgroundColor:foregroundColor:fontTrait`, where colors is a `AARRGGBB` and `fontTrait` is either `b` for bold or `i` for italic.

On next console output lines containing pattern will be attributed with matching options. 

You can find example config in `.xccolors.json`.
