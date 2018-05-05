# Remove Prototypes
A mod for the game Factorio, for removing arbitrary prototypes from the game.

Given a list of prototype names, or types and names, this mod will remove those prototypes during the data loading stage of the game, as best as it can. The named prototypes will be removed unless they are the last of their kind. References to named prototypes will also be removed, such as removing a named item from recipe ingredients and results, or a named technology from other technologies' prerequisites.