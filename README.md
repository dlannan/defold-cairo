# Cairo for Defold

The aim is to provide a cairo based UI for Defold to make building interesting and modern interfaces easier.

The current systems uses a state manager to control the flow of UI execution. This is _not_ required. This is to make building GUI applications a little easier and it maps in nicely to Defold state processes.

## Development
Feb 2021:
In its current state its very rudimentary. It has support for a number of widget types and some very basic V1.0 svg.
It is completely usable though. Buttons, listboxes, MultiImage, Sliders, and much more is available and working.
Sample:

![alt text](https://github.com/dlannan/defold-cairo/blob/main/data/screenshots/demo-2021-02-19_00-42.png "Demo V0.1")

Only tested on Liunx, but should work on Windows and OSX. Android and IOS I need to build cairo for them to be usable. 

Im working on:
- making this SVG import much better (support wider SVG versions).
- improving reliability for some of the widgets (slider)
- Adding more widgets
- A better, simple demonstration of all the widgets.

## Notes
Performance is average. A full screen of 1440x1050 with large widgets will get around 50fps on a mid level PC. 
All drawing is CPU compositied - which is _slow_ and its done every frame. This will change. Eventually all rendering will be via cached surfaces, which should result in 10-100x performance improvements (depending on the dynamic nature of your UI). 

---
