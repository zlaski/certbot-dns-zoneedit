#!/bin/bash
pushd `dirname $0`
python3 -m pip install -e .
popd
