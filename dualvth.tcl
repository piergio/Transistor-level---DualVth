proc dualVth {args} {

	parse_proc_arguments -args $args results
	set lvt $results(-lvt)
	set constraint $results(-constraint)

	#################################
	### INSERT YOUR COMMANDS HERE ###
	#################################

	set cellsCollection [get_cells]
	set sizeCollection [sizeof_collection $cellsCollection]

	puts "Dual vth swapping procedure\n\n"
	set LVTPercentage $lvt
	set HVTPercentage [expr 1 - $LVTPercentage]
	set swapIndex [expr round($sizeCollection * $HVTPercentage)]

	set myList ""
	set powerBefore 0
	set powerAfter 0

	foreach_in_collection pt $cellsCollection {

		set cellName [get_attribute $pt full_name]
		set cellLeakage [get_attribute $pt leakage_power]
		set cellSlack [get_attribute [get_timing_paths -through $pt] slack]
		set powerBefore [expr $powerBefore + $cellLeakage]
		lappend myList [list $cellName [expr $cellLeakage*$cellSlack]]
	}

	set myList [lsort -real -decreasing -index 1 $myList]

	if {$constraint == "soft"} {

		set tmp [expr $swapIndex / 2]
		myFun 0 $tmp true $myList

	} elseif {$constraint == "hard"} {

		swap 0 $swapIndex $myList

	} else {

		puts "Invalid contraint argument : $constraint"
	}

	foreach_in_collection pt [get_cells] {

		set powerAfter [expr $powerAfter + [get_attribute $pt leakage_power]]
	}

	puts "\n\n------------- Dual vth completed -------------\n\n"
	puts "Leakage power : \nBefore swapping =\t $powerBefore \nAfter swapping  =\t $powerAfter\n\n\n\n"
	return
}

define_proc_attributes dualVth \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-lvt "maximum % of LVT cells in range [0, 1]" lvt float required}
	{-constraint "optimization effort: soft or hard" constraint one_of_string {required {values {soft hard}}}}
}


proc swap {start stop myList} {

	for {set i $start} {$i < $stop} {incr i} {

		set c [get_cell [lindex [lindex $myList $i] 0]]

		puts [get_attribute $c ref_name]

		set tmp ""
		set k1 ""
		set k2 ""
		set k3 ""
		set pa "_"

		[regexp {(.*)L(.*)\_(.*)} [get_attribute $c ref_name] -> k1 k2 k3]

		if { $k2 == ""} {

			set tmp $k3
		} else {

			set tmp $k2$pa$k3
		}

		foreach_in_collection pp [get_alternative_lib_cells $c] {

				if { [get_attribute $pp threshold_voltage_group] == "HVT" } {

						if { [string match *$tmp [get_attribute $pp full_name]]} {

								set new [get_attribute $pp full_name]
						}
				}
		}
		[size_cell $c CORE65LPHVT_nom_1.20V_25C.db:$new]
	}
}

proc goBack {start stop myList} {

	for {set i $start} {$i <= $stop} {incr i} {

		set c [get_cell [lindex [lindex $myList $i] 0]]

		set ref_name [get_attribute $c ref_name]

		set vth ""
	  regexp {_L(L|H)S_} $ref_name -> vth

		if { $vth == ""} {

	    regexp {_L(L|H)_} $ref_name -> vth
	  }

	  if {$vth == "H"} {

			set tmp ""

			set tmp ""
			set k1 ""
			set k2 ""
			set k3 ""
			set pa "_"

			[regexp {(.*)H(.*)\_(.*)} [get_attribute $c ref_name] -> k1 k2 k3]

			if { $k2 == ""} {

				set tmp $k3
			} else {

				set tmp $k2$pa$k3
			}

			foreach_in_collection pp [get_alternative_lib_cells $c] {

					if { [get_attribute $pp threshold_voltage_group] == "LVT" } {

							if { [string match *$tmp [get_attribute $pp full_name]]} {

									set new [get_attribute $pp full_name]
							}
					}
			}
			[size_cell $c CORE65LPLVT_nom_1.20V_25C.db:$new]
		}
	}
}

proc myFun {start stop dir list} {

	if {$dir == true} {

		swap $start $stop $list
	} else {

		goBack $stop [expr round($stop + ($stop - $start))] $list
	}

	if { $start == $stop} {

		return
	}

	if { [get_attribute [get_timing_paths] slack] >= 0} {

		myFun $stop [expr round($stop + ($stop - $start)/2)] true $list
	} else {

		myFun $start [expr round($start + ($stop - $start)/2)] false $list
	}
}