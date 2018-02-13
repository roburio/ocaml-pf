open Rresult


let () =
  Printexc.record_backtrace true ;
  Logs.set_reporter @@ Logs_fmt.reporter ~dst:Format.std_formatter () ;
  Logs.(set_level @@ Some Debug)

open Pf.Parse

let alc_rule = Alcotest.testable pp_pf_rule (fun a b -> a = b)
(*into_lines*)

let alc_qubes = Alcotest.testable Pf.Parse_qubes.pp_rule (fun a b -> a = b)

open Pf.Parse_qubes

let host_addr str = (* helper function *)
  Host_addr { negated = false ;
              if_or_cidr =
                CIDR (Ipaddr.Prefix.of_string str |> function Some x -> x)
            }

let qubes str =
  Pf.Parse_qubes.parse_qubes_v4
    ~source_ip:Ipaddr.(of_string "127.0.0.1" |> function Some x -> x)
    ~number:0 str

let test_qubes_empty () =
  Alcotest.(check @@ result reject string) "empty fails"
    (Error ": not enough input") (qubes "")

let test_qubes_only_action () =
  Alcotest.(check @@ result alc_qubes string) "action=accept"
    (Ok { Pf.Parse_qubes.source_ip = Ipaddr.(V4 V4.localhost) ;
          number = 0 ;
          rule = { Pf.Parse.empty_pf_rule with
                   action = Pass ;
                   quick = true ;
                   hosts = From_to
                       { from_host = `hosts [host_addr "127.0.0.1/32" ] ;
                         from_port = [] ; from_os = [] ; to_host = `any ;
                         to_port = [] ;
                       } ;
                 }
        }
    )
    (qubes "action=accept")

let test_qubes_dns () =
  Alcotest.(check @@ result alc_qubes string) "action=accept dst4=8.8.8.8 proto=udp dstports=53-53"
    (Ok { Pf.Parse_qubes.source_ip = Ipaddr.(V4 V4.localhost) ;
          number = 0 ;
          rule = { Pf.Parse.empty_pf_rule with
                   action = Pass ;
                   quick = true ;
                   af = Some Inet ;
                   protospec = Some (Proto_list [Name (String "udp")]) ;
                   hosts = From_to
                       { from_host = `hosts
                             [host_addr "127.0.0.1/32" ] ;
                         from_port = [] ; from_os = [] ;
                         to_host = `hosts [host_addr "8.8.8.8/32"] ;
                         to_port = [ Binary (Range_inclusive (53,53))] ;
                       } ;
                 }
        }
    )
    (qubes "action=accept dst4=8.8.8.8 proto=udp dstports=53-53")

let test_qubes_ipv6 () =
  Alcotest.(check @@ result alc_qubes string)
    "action=drop dst6=2a00:1450:4000::/37 proto=tcp"
    (Ok { Pf.Parse_qubes.source_ip = Ipaddr.(V4 V4.localhost) ;
          number = 0 ;
          rule = { Pf.Parse.empty_pf_rule with
                   action = Block None ;
                   quick = true ;
                   af = Some Inet6 ;
                   protospec = Some (Proto_list [Name (String "tcp")]) ;
                   hosts = From_to
                       { from_host = `hosts
                             [host_addr "127.0.0.1/32" ] ;
                         from_port = [] ; from_os = [] ;
                         to_host = `hosts [host_addr "2a00:1450:4000::/37"] ;
                         to_port = [] ;
                       } ;
                 }
        }
    )
    (qubes "action=drop dst6=2a00:1450:4000::/37 proto=tcp")

let test_qubes_unimplemented () =
  Alcotest.(check @@ result alc_qubes string)
    "action=accept specialtarget=dns"
    (Ok { Pf.Parse_qubes.source_ip = Ipaddr.(V4 V4.localhost) ;
          number = 0 ;
          rule = { Pf.Parse.empty_pf_rule with
                   action = Pass ;
                   quick = true ;
                   hosts = From_to
                       { from_host = `hosts
                             [host_addr "127.0.0.1/32" ] ;
                         from_port = [] ; from_os = [] ;
                         to_host = `any; to_port = [] ;
                       } ;
                 }
        }
    )
    (qubes "action=accept specialtarget=dns") ;
  Alcotest.(check @@ result alc_qubes string)
    "action=drop proto=tcp specialtarget=dns"
    (Ok { Pf.Parse_qubes.source_ip = Ipaddr.(V4 V4.localhost) ;
          number = 0 ;
          rule = { Pf.Parse.empty_pf_rule with
                   action = Block None ;
                   quick = true ;
                   protospec = Some (Proto_list [Name (String "tcp")]) ;
                   hosts = From_to
                       { from_host = `hosts
                             [host_addr "127.0.0.1/32" ] ;
                         from_port = [] ; from_os = [] ;
                         to_host = `any; to_port = [] ;
                       } ;
                 }
        }
    )
    (qubes "action=drop proto=tcp specialtarget=dns")

let tests =
  [ "parse_qubes [QubesOS v4 firewall format adapter]",
    [ "empty", `Quick, test_qubes_empty ;
      "action=accept", `Quick, test_qubes_only_action ;
      "action=accept dst4=8.8.8.8 proto=udp dstports=53-53", `Quick,
      test_qubes_dns ;
      "Handling of IPv6 rules", `Quick, test_qubes_ipv6;
      "action=accept specialtarget=dns", `Quick, test_qubes_unimplemented
    ]
  ]

let () =
  Alcotest.run "ocaml-pf test suite" tests
