# Overview

There are many greate plugins for running code from inside nvim, but this runner has been created to enable running projects as a whole.
When run in RunProject mode it will automatically use the first ```.runner.yaml``` configuration file it encounters.

# Configuration

Projects are configured per-project using ```.runner.yaml``` file.

List of possible keywords:
- 'mode': \[float, term\] specifies mode the nvim terminal will be run in
- 'project': a string of commands to run when starting project

# Disclaimer

This plugin is being developed as a personal project with AI support and as such is suspectible to changes, some of which can lead to broken configuration.
