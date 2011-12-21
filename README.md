# GroundControl

GroundControl is a test runner / builder for your Rails apps.

## Usage / Hacking

If you want to try GroundControl or see how it works. This is what you'll need to do:

* Install RVM.
* Install ruby 1.8.7 with RVM.
* In your 1.8.7 RVM install the gems: git, grit, tinder, geckoboard-push.
* Create a groundcontrol workspace somewhere with a directory that looks like. In the following example I created "testbuilds" as my workspace.

```
testbuilds
 \- config
    \ projects.yml
```

* The projects.yml should look like:

```
---
projects:
  my_project_name:
    git: <git clone url>
```

* Run the *groundcontrol* command in the *testbuilds* directory.