/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import <React/RCTBridge.h>
#import <React/RCTRootView.h>

#if RCT_NEW_ARCH_ENABLED

#ifndef RCT_USE_HERMES
#if __has_include(<reacthermes/HermesExecutorFactory.h>)
#define RCT_USE_HERMES 1
#else
#define RCT_USE_HERMES 0
#endif
#endif

#if RCT_USE_HERMES
#import <reacthermes/HermesExecutorFactory.h>
#else
#import <React/JSCExecutorFactory.h>
#endif

#import <ReactCommon/RCTTurboModuleManager.h>
#endif

RCT_EXTERN_C_BEGIN

void RCTAppSetupPrepareApp(UIApplication *application);
UIView *RCTAppSetupDefaultRootView(RCTBridge *bridge, NSString *moduleName, NSDictionary *initialProperties);

#if RCT_NEW_ARCH_ENABLED
id<RCTTurboModule> RCTAppSetupDefaultModuleFromClass(Class moduleClass);
std::unique_ptr<facebook::react::JSExecutorFactory> RCTAppSetupDefaultJsexecutorFactory(
    RCTBridge *bridge,
    RCTTurboModuleManager *turboModuleManager);
#endif

RCT_EXTERN_C_END
