# Run post-synthesis checks/write report
source [file join [file dirname [info script]] .. project_context.tcl]
check_blackboxes synthesis 1
report_utilization -file [file join $report_dir synthesis_utilization.rpt]
