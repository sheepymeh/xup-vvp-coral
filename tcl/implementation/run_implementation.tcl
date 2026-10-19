# Resume implementation from synthesized project
if {
    [catch {
        open_project [lindex $argv 0]
        source [file join [file dirname [info script]] .. project_context.tcl]
        source [file join $root_dir tcl implementation macros.tcl]
        set_param general.maxThreads $XUP_BUILD_JOBS

        set synthesis [get_runs {synth_1}]
        if {[get_property PROGRESS $synthesis] ne "100%" || [get_property NEEDS_REFRESH $synthesis]} {
            error "Synthesis is incomplete or stale"
        }

        xup_implementation::configure_implementation
        puts "XUP_REUSE_SYNTHESIS [get_property DIRECTORY $synthesis]"

        # Launch Edalize
        set implementation_started [clock milliseconds]
        source [file join $xup_work_dir [current_project]_run.tcl]
        set runtime [open [file join $report_dir implementation_runtime.txt] w]
        puts $runtime "elapsed_seconds=[expr {([clock milliseconds] - $implementation_started) / 1000.0}]"
        close $runtime
        close_project
    } message options]
} {
    puts stderr $message
    puts stderr [dict get $options -errorinfo]
    exit 1
}
