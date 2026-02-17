#!/bin/bash

# Default item properties applied to all further items
default=(
  padding_left=5
  padding_right=5
  icon.font="Hack Nerd Font:Bold:17.0"
  label.font="SF Pro:Semibold:14.0"
  icon.color=$COLOR_TEXT
  label.color=$COLOR_TEXT
  icon.padding_left=4
  icon.padding_right=4
  label.padding_left=4
  label.padding_right=4
)
sketchybar --default "${default[@]}"
