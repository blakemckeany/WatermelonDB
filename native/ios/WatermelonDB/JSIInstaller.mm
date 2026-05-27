#import "JSIInstaller.h"
#import "Database.h"

extern "C" void installWatermelonJSI(RCTCxxBridge *bridge) {
    NSLog(@"🍉 FORK LOADED: WatermelonDB (MyOrchard dev fork) — iOS JSI install");
    if (bridge.runtime == nullptr) {
        return;
    }

    jsi::Runtime *runtime = (jsi::Runtime*) bridge.runtime;
    assert(runtime != nullptr);
    watermelondb::Database::install(runtime);
}
