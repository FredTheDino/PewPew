const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("ZigZag", "src/main.zig");
    exe.setBuildMode(mode);

    // Libraries
    exe.addLibPath("lib/linux");
    exe.addIncludeDir("inc");
    exe.addCSourceFile("inc/glad/glad.c", [][]const u8{"-std=c99"});
    exe.addCSourceFile("inc/stb_image_impl.c", [][]const u8{"-std=c99"});
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2main");

    const run_cmd = exe.run();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
