#!/bin/bash

hash ruby 2>/dev/null
if [[ $? != 0 ]]; then
   source /etc/profile.d/chruby.sh
fi
chruby {{ .RubyVersion }}

read INPUT

echo $INPUT | {{ .DummyCPIPath }} {{ .BaseDir }}/director.yml