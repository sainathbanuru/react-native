#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -o pipefail
set -e

GENERATED_SRCS_DIR="$DERIVED_FILE_DIR/generated/source/codegen"
TEMP_OUTPUT_DIR="$GENERATED_SRCS_DIR/out"
GENERATED_SCHEMA_FILE="$GENERATED_SRCS_DIR/schema.json"

cd "$RCT_SCRIPT_RN_DIR"

CODEGEN_REPO_PATH="$RCT_SCRIPT_RN_DIR/packages/react-native-codegen"
CODEGEN_NPM_PATH="$RCT_SCRIPT_RN_DIR/../react-native-codegen"
CODEGEN_CLI_PATH=""

error () {
    echo "$1"
    "[Codegen] $1" >> "${SCRIPT_OUTPUT_FILE_0}" 2>&1
    exit 1
}

# Determine path to react-native-codegen
if [ -d "$CODEGEN_REPO_PATH" ]; then
    CODEGEN_CLI_PATH=$(cd "$CODEGEN_REPO_PATH" && pwd)
elif [ -d "$CODEGEN_NPM_PATH" ]; then
    CODEGEN_CLI_PATH=$(cd "$CODEGEN_NPM_PATH" && pwd)
else
    error "error: Could not determine react-native-codegen location in $CODEGEN_REPO_PATH or $CODEGEN_NPM_PATH. Try running 'yarn install' or 'npm install' in your project root."
fi

find_node () {
    # shellcheck disable=SC1091
    source "$RCT_SCRIPT_RN_DIR/scripts/find-node.sh"

    NODE_BINARY="${NODE_BINARY:-$(command -v node || true)}"
    if [ -z "$NODE_BINARY" ]; then
        error "error: Could not find node. Make sure it is in bash PATH or set the NODE_BINARY environment variable."
    fi
}

setup_dirs () {
    set +e
    rm -rf "$GENERATED_SRCS_DIR"
    set -e

    mkdir -p "$GENERATED_SRCS_DIR" "$TEMP_OUTPUT_DIR"

    # Clear output files
    true > "${SCRIPT_OUTPUT_FILE_0}"
}

describe () {
    message="

    >>>>> $1

    "
    echo "$message" >> "${SCRIPT_OUTPUT_FILE_0}" 2>&1
}

runSpecCodegen () {
    "$NODE_BINARY" "scripts/generate-specs-cli.js" --platform ios --schemaPath "$GENERATED_SCHEMA_FILE" --outputDir "$1" --libraryName "$RCT_SCRIPT_LIBRARY_NAME" --libraryType "$2"
}

generateCodegenSchemaFromJavaScript () {
    describe "Generating codegen schema from JavaScript"

    SRCS_PATTERN="$RCT_SCRIPT_JS_SRCS_PATTERN"
    SRCS_DIR="$RCT_SCRIPT_JS_SRCS_DIR"
    if [ "$SRCS_PATTERN" ]; then
        JS_SRCS=$(find "$PODS_TARGET_SRCROOT/$SRCS_DIR" -type f -name "$SRCS_PATTERN" -print0 | xargs -0)
        echo "$RCT_SCRIPT_FILE_LIST" >> "${SCRIPT_OUTPUT_FILE_0}" 2>&1
    else
        JS_SRCS="$\{PODS_TARGET_SRCROOT\}/$SRCS_DIR"
        echo "$RCT_SCRIPT_JS_SRCS_DIR" >> "${SCRIPT_OUTPUT_FILE_0}" 2>&1
    fi

    # shellcheck disable=SC2086
    # $JS_SRCS not having double quotations is intentional
    "$NODE_BINARY" "$CODEGEN_CLI_PATH/lib/cli/combine/combine-js-to-schema-cli.js" "$GENERATED_SCHEMA_FILE" $JS_SRCS
}

generateCodegenArtifactsFromSchema () {
    describe "Generating codegen artifacts from schema"
    pushd "$RN_DIR" >/dev/null || exit 1
        if [ "$RCT_SCRIPT_LIBRARY_TYPE" = "all" ]; then
            runSpecCodegen "$TEMP_OUTPUT_DIR/$RCT_SCRIPT_CODEGEN_MODULE_DIR/$RCT_SCRIPT_LIBRARY_NAME" "modules"
            runSpecCodegen "$TEMP_OUTPUT_DIR/$RCT_SCRIPT_CODEGEN_COMPONENT_DIR/$RCT_SCRIPT_LIBRARY_NAME" "components"
        elif [ "$RCT_SCRIPT_LIBRARY_TYPE" = "components" ]; then
            runSpecCodegen "$TEMP_OUTPUT_DIR/$RCT_SCRIPT_CODEGEN_COMPONENT_DIR/$RCT_SCRIPT_LIBRARY_NAME" "$RCT_SCRIPT_LIBRARY_TYPE"
        elif [ "$RCT_SCRIPT_LIBRARY_TYPE" = "modules" ]; then
            runSpecCodegen "$TEMP_OUTPUT_DIR/$RCT_SCRIPT_CODEGEN_MODULE_DIR/$RCT_SCRIPT_LIBRARY_NAME" "$RCT_SCRIPT_LIBRARY_TYPE"
        fi
    popd >/dev/null || exit 1
}

generateArtifacts () {
    describe "Generating codegen artifacts"
    pushd "$RCT_SCRIPT_RN_DIR" >/dev/null || exit 1
        "$NODE_BINARY" "scripts/generate-artifacts.js" --path "$RCT_SCRIPT_APP_PATH" --outputPath "$TEMP_OUTPUT_DIR" --fabricEnabled "$RCT_SCRIPT_FABRIC_ENABLED" --configFileDir "$RCT_SCRIPT_CONFIG_FILE_DIR"
    popd >/dev/null || exit 1
}

moveOutputs () {
    mkdir -p "$RCT_SCRIPT_OUTPUT_DIR"

    # Copy all output to output_dir
    cp -R "$TEMP_OUTPUT_DIR/" "$RCT_SCRIPT_OUTPUT_DIR" || exit 1
    echo "$LIBRARY_NAME output has been written to $RCT_SCRIPT_OUTPUT_DIR:" >> "${SCRIPT_OUTPUT_FILE_0}" 2>&1
    ls -1 "$RCT_SCRIPT_OUTPUT_DIR" >> "${SCRIPT_OUTPUT_FILE_0}" 2>&1
}

withCodgenDiscovery () {
    setup_dirs
    find_node
    generateArtifacts
    moveOutputs
}

noCodegenDiscovery () {
    setup_dirs
    find_node
    generateCodegenSchemaFromJavaScript
    generateCodegenArtifactsFromSchema
    moveOutputs
}

if [ "$RCT_SCRIPT_TYPE" = "withCodegenDiscovery" ]; then
    withCodgenDiscovery "$@"
else
    noCodegenDiscovery "$@"
fi

echo 'Done.' >> "${SCRIPT_OUTPUT_FILE_0}" 2>&1
