use std::any::type_name;
use std::any::Any;
use std::collections::HashMap;
use anyhow::{anyhow, Result};
use nmea::sentences::{GnssType};
use serde_json::{Map, Value};
use nmea::{parse_nmea_sentence, parse_str, Nmea, ParseResult, Satellite};

use crate::utils::inc_param;
use crate::utils::put_param;
use crate::utils::TALKER_NONE;
use once_cell::sync::Lazy;

const TYPE_KEY: &str ="type";
const TYPE_NMEA: &str = "nmea";

pub const TALKER_GP: &str = "GP"; // GPS
pub const TALKER_GL: &str = "GL"; // GLONASS
pub const TALKER_GA: &str = "GA"; // GALILEO
pub const TALKER_GB: &str = "GB"; // BEIDOU
pub const TALKER_GQ: &str = "GQ"; // QZSS
pub const TALKER_GI: &str = "GI"; // NAVIC
pub const TALKER_UBX: &str = "UBX";
pub const TALKER_PUBX_NMEA_PREFIX: &str = "$PUBX";

const PUBX_LOCATION_PARAMS: Lazy<HashMap<usize, String>> = Lazy::new( || {
        let mut map = HashMap::new();
        map.insert(2, "POSITION_time".to_string());
	map.insert(3, "POSITION_lat".to_string());
	map.insert(4,"POSITION_NS".to_string());
	map.insert(5,"POSITION_long".to_string());
        map.insert(6,"POSITION_EW".to_string());
        map.insert(7,"POSITION_altRef".to_string());
	map.insert(8,"POSITION_navStat".to_string());
        map.insert(9,"POSITION_hAcc".to_string());
        map.insert(10,"POSITION_vAcc".to_string());
        map.insert(11,"POSITION_SOG".to_string());
        map.insert(12,"POSITION_COG".to_string());
        map.insert(13,"POSITION_vVel".to_string());
        map.insert(14,"POSITION_diffAge".to_string());
        map.insert(15,"POSITION_HDOP".to_string());
        map.insert(16,"POSITION_VDOP".to_string());
        map.insert(17,"POSITION_TDOP".to_string());
        map.insert(18,"POSITION_numSvs".to_string());
	map
});

pub fn get_talker_id_for_gnss_system_id_int(gnss_system_id: u32) -> Option<&'static str> {
    match gnss_system_id {
        1 => Some(TALKER_GP),
        2 => Some(TALKER_GL),
        3 => Some(TALKER_GA),
        4 => Some(TALKER_GB),
        5 => Some(TALKER_GQ),
        _ => None,
    }
}

pub fn get_talker_id_for_gt(gt: &GnssType) -> Option<&'static str> {
    match gt {
        GnssType::Gps => Some(TALKER_GP),
        GnssType::Glonass => Some(TALKER_GL),
        GnssType::Galileo => Some(TALKER_GA),
        GnssType::Beidou => Some(TALKER_GB),
        GnssType::Qzss => Some(TALKER_GQ),
	GnssType::NavIC => Some(TALKER_GI),
        _ => None,
    }
}

pub fn get_gsa_talker_id_from_gsa_nmea(nmea: &str, sids: &[u32]) -> Option<&'static str> {
    if !nmea.contains(',') {
        return None;
    }

    const GSA_SYSTEM_ID_NMEA_CSV_INDEX: usize = 18;
    let parts: Vec<&str> = nmea.split(',').collect();

    // Try to parse explicit system ID at index 18
    if parts.len() > GSA_SYSTEM_ID_NMEA_CSV_INDEX {
	let gsi = parts[GSA_SYSTEM_ID_NMEA_CSV_INDEX].trim();

	let mut part = parts[GSA_SYSTEM_ID_NMEA_CSV_INDEX].trim();

	// Cut off any checksum part like "4*05"
	if let Some(star_pos) = part.find('*') {
	    part = &part[..star_pos];
	}

	println!("gsi: {part}");
	
	if let Ok(id) = part.parse::<u32>() {
	    return get_talker_id_for_gnss_system_id_int(id);
	}
    }

    // Otherwise infer from satellite IDs
    let mut is_gps = false;
    let mut is_glonass = false;

    for &sid in sids {
        if (1..=32).contains(&sid) {
            is_gps = true;
        } else if (65..=96).contains(&sid) {
            is_glonass = true;
        }
    }

    if is_gps {
        Some(TALKER_GP)
    } else if is_glonass {
        Some(TALKER_GL)
    } else {
        None
    }
    
}


pub fn parse_nmea_pkt(params: &mut HashMap<String, Value>, parser: &mut Nmea, pkt: Vec<u8>) -> Result<Map<String, Value>> {
    let mut ret:Map<String, Value> = Map::new();
    ret.insert(TYPE_KEY.to_string(), Value::from(TYPE_NMEA));
    let nmea_str_pretrim = String::from_utf8(pkt).map_err(|e| {anyhow!("from_utf8 error: {e}")})?;
    let nmea_str = nmea_str_pretrim.trim();
    println!("parse_neam_pkt: nmea_str: {}", nmea_str);

    if nmea_str.starts_with(TALKER_PUBX_NMEA_PREFIX) {
	println!("got pubx");
	let parts: Vec<&str> = nmea_str.split(',').collect();
	if parts.len() > 1 {
	    let p1 = parts.get(1).unwrap();
	    if p1.to_string() == "00" {
		let emsg = "pubx position parse error: {e}";
		for (k, v) in PUBX_LOCATION_PARAMS.iter() {
		    
		    put_param(params, TALKER_UBX.to_string(), v.clone(), Value::from(parts.get(*k).ok_or(emsg).map_err(|e| {anyhow!(emsg)})?.to_string()));
		}
	    }
	}
	return Ok(ret);
    }
    
    let sentence = parse_nmea_sentence(nmea_str).map_err(|e| {anyhow!("parse_nmea_sentence error: {e}")})?;
    let talker_id = sentence.talker_id;
    let sentence_id = sentence.message_id.as_str();
    ret.insert("talker".to_string(), Value::from(talker_id));
    ret.insert("name".to_string(), Value::from(sentence_id));
    ret.insert("nmea".to_string(), Value::from(nmea_str));
    let parser = parser;
    let sentence_counter = format!("{sentence_id}_count");
    inc_param(params, talker_id.to_string(), sentence_counter);
    let fix_type = parser.parse(nmea_str).map_err(|e| anyhow!("{e}"))?;
    let pr = parse_str(nmea_str).map_err(|e| {anyhow!("{e}")})?;
    let sat_groups = parser.satellites();
    println!("sat_groups: {:?} fix prns: {:?}", sat_groups, parser.fix_satellites_prns);

    match pr {
        ParseResult::AAM(_) => {}
        ParseResult::ALM(_) => {}
        ParseResult::APA(_) => {}
        ParseResult::BOD(_) => {}
        ParseResult::BWC(_) => {}
        ParseResult::BWW(_) => {}
        ParseResult::DBK(_) => {}
        ParseResult::DPT(_) => {}
        ParseResult::GBS(_) => {}
        ParseResult::GGA(_) => {
	    
        }
        ParseResult::GLL(_) => {}
        ParseResult::GNS(_) => {}
        ParseResult::GSA(gsa) => {

	    let sids = gsa.fix_sats_prn;
	    if let Some(talker) = get_gsa_talker_id_from_gsa_nmea(nmea_str, &sids) {
		//println!("Detected talker: {}", talker);
		put_param(params, format!("{}", talker), "n_sats_used".to_string(), Value::from(sids.len()));
	    } else {
		//println!("No talker detected");
	    }
	}
        ParseResult::GST(_) => {}
        ParseResult::GSV(_) => {}
        ParseResult::HDT(_) => {}
        ParseResult::MDA(_) => {}
        ParseResult::MTW(_) => {}
        ParseResult::MWV(_) => {}
        ParseResult::RMC(rmc) => {
	    let rmc_ts = match (rmc.fix_date, rmc.fix_time) {
		(Some(fd), Some(ft)) => {
		    fd.and_time(ft).and_utc().timestamp_millis()
		}
		_ => -1,
            };
	    
	    put_param(params, talker_id.to_string(), "rmc_ts".to_string(), Value::from(rmc_ts));

	    let mut type_to_sat_map: HashMap<GnssType, Vec<Satellite>> = HashMap::new();
	    for sg in sat_groups {
		type_to_sat_map.entry(sg.gnss_type()).or_default().push(sg.clone());
	    }
	    
	    for (gt, sats) in &type_to_sat_map {
		let talker = get_talker_id_for_gt(&gt);
		match talker {
		    Some(t) => {
			put_param(params, format!("{}", t), "n_sats_in_view".to_string(), Value::from(sats.len()));
		    }
		    None => {
		    }
		}
		
	    }


	    //dump parser state
            put_param(params, TALKER_NONE.to_string(), "fix_type".to_string(), Value::from(format!("{:?}", fix_type)));
            put_param(params, TALKER_NONE.to_string(), "lat".to_string(), Value::from(parser.latitude));
            put_param(params, TALKER_NONE.to_string(), "lon".to_string(), Value::from(parser.longitude));
            put_param(params, TALKER_NONE.to_string(), "alt".to_string(), Value::from(parser.altitude));
            //Get height/separation of geoid above WGS84 ellipsoid, i.e. difference between WGS-84 earth ellipsoid and mean sea level.
            put_param(params, TALKER_NONE.to_string(), "geoidal_height".to_string(), Value::from(parser.geoid_separation));
	    //println!("set n_sats_used: {:?}", parser.num_of_fix_satellites);
            put_param(params, TALKER_NONE.to_string(), "n_sats_used".to_string(), Value::from(parser.num_of_fix_satellites));
	    //put_param(talker_id, "ellipsoidal_height", gga.getAltitude() + gga.getGeoidalHeight());
	    match parser.altitude {
		Some(alt) => {
		    match parser.geoid_separation {
			Some(sep) => {
			    put_param(params, TALKER_NONE.to_string(), "ellipsoidal_height".to_string(), Value::from(alt+sep));
			}
			None => {}
		    }
		}
		None => {}
	    }

	    
            put_param(params, TALKER_NONE.to_string(), "vdop".to_string(), Value::from(parser.vdop));
            put_param(params, TALKER_NONE.to_string(), "hdop".to_string(), Value::from(parser.hdop));
            put_param(params, TALKER_NONE.to_string(), "pdop".to_string(), Value::from(parser.pdop));
            put_param(params, TALKER_NONE.to_string(), "speed_over_ground".to_string(), Value::from(parser.speed_over_ground));
            put_param(params, TALKER_NONE.to_string(), "true_course".to_string(), Value::from(parser.true_course));

	    let psd = serde_json::to_value(&params)?;
	    ret.insert("state".to_string(), psd);
        }
        ParseResult::TTM(_) => {}
        ParseResult::TXT(_) => {}
        ParseResult::VHW(_) => {}
        ParseResult::VTG(_) => {}
        ParseResult::WNC(_) => {}
        ParseResult::ZDA(_) => {}
        ParseResult::ZFO(_) => {}
        ParseResult::ZTG(_) => {}
        ParseResult::PGRMZ(_) => {}
        ParseResult::Unsupported(us) => {
	    println!("unsupported: {us}");
	}
    }

    
    Ok(ret)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::gnss_parser::queue_and_parse;
    use nmea::SentenceType;
    use serde_json::json;

    #[test]
    fn test_nmea_parse_map_state()
    {
	let nav_st = vec![SentenceType::RMC];
	let mut params: HashMap<String, Value> = HashMap::new();
	let mut parser: Nmea = Nmea::create_for_navigation(&nav_st).unwrap();
	let example_nmea_gga = "$GNGGA,045115.00,0000.000,N,00000.000,E,1,12,0.60,3.0,M,-13.0,M,,*6F\n";
	let _ex1 = format!("chad_yak_pai_wangkeaw_leaw{}", example_nmea_gga);
	let ex1 = _ex1.as_str();
	let inputs = vec![
	    example_nmea_gga,
            "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n",
            "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\r\n",
            "$GNRMC,095520.00,A,2733.35607,S,15302.15703,E,0.042,,240719,,,A,V*0A\n",

            "03:01:42  $GNGSA,A,3,17,05,12,19,09,28,02,06,,,,,1.10,0.49,0.99,1*03\n",
            "03:01:42  $GNGSA,A,3,81,67,66,79,78,,,,,,,,1.10,0.49,0.99,2*06\n",
            "03:01:42  $GNGSA,A,3,04,33,19,31,24,12,,,,,,,1.10,0.49,0.99,3*05\n",
            "03:01:42  $GNGSA,A,3,23,28,27,08,10,07,13,16,09,,,,1.10,0.49,0.99,4*05\n",
            "$GNGSA,A,3,26,31,10,32,14,16,25,20,18,22,41,,1.34,0.74,1.12*16\n",

            "03:52:31  $GPGSV,3,1,12,02,30,352,41,05,67,295,38,06,18,039,28,09,03,049,37,1*68\n",
            "03:52:31  $GPGSV,3,2,12,12,44,295,46,13,32,171,31,15,12,204,32,17,34,106,31,1*6B\n",
            "03:52:31  $GPGSV,3,3,12,19,43,089,27,24,06,235,,25,08,315,,28,06,154,,1*6C\n",

            "03:52:31  $GPGSV,3,1,12,02,30,352,,05,67,295,23,06,18,039,35,09,03,049,,6*68\n",
            "03:52:31  $GPGSV,3,2,12,12,44,295,35,13,32,171,,15,12,204,23,17,34,106,25,6*6F\n",
            "03:52:31  $GPGSV,3,3,12,19,43,089,,24,06,235,,25,08,315,,28,06,154,,6*6E\n",

            "03:52:31  $GLGSV,3,1,10,66,14,029,43,67,66,046,39,68,51,193,,69,03,202,,1*76\n",
            "03:52:31  $GLGSV,3,2,10,78,05,173,,79,23,220,28,80,16,275,,81,26,053,34,1*71\n",
            "03:52:31  $GLGSV,3,3,10,82,20,360,32,88,08,097,,1*73\n",
            "03:52:31  $GLGSV,3,1,10,66,14,029,33,67,66,046,09,68,51,193,,69,03,202,,3*70\n",
            "03:52:31  $GLGSV,3,2,10,78,05,173,,79,23,220,21,80,16,275,,81,26,053,27,3*78\n",
            "03:52:31  $GLGSV,3,3,10,82,20,360,26,88,08,097,,3*74\n",
            "03:52:31  $GAGSV,3,1,10,01,14,165,18,04,53,180,30,09,07,208,22,11,05,307,,7*72\n",
            "03:52:31  $GAGSV,3,2,10,12,29,354,41,19,52,068,24,24,29,280,43,26,00,093,11,7*75\n",
            "03:52:31  $GAGSV,3,3,10,31,40,214,28,33,26,051,30,7*7A\n",
            "03:52:31  $GAGSV,3,1,10,01,14,165,,04,53,180,25,09,07,208,,11,05,307,,2*7A\n",
            "03:52:31  $GAGSV,3,2,10,12,29,354,33,19,52,068,23,24,29,280,33,26,00,093,,2*75\n",
            "03:52:31  $GAGSV,3,3,10,31,40,214,15,33,26,051,,2*72\n",
            "03:52:31  $GBGSV,5,1,18,01,45,099,,02,68,253,,03,77,122,,04,23,094,,1*79\n",
            "03:52:31  $GBGSV,5,2,18,05,40,264,,06,54,132,10,07,42,177,30,08,28,020,30,1*7F\n",
            "03:52:31  $GBGSV,5,3,18,09,43,169,,10,55,209,27,13,33,352,39,16,53,145,37,1*7F\n",
            "03:52:31  $GBGSV,5,4,18,18,37,350,,20,16,216,,23,08,156,,27,38,003,39,1*79\n",
            "03:52:31  $GBGSV,5,5,18,28,37,072,35,30,04,321,,1*75\n",
            "03:52:31  $GBGSV,5,1,18,01,45,099,,02,68,253,,03,77,122,,04,23,094,,3*7B\n",
            "03:52:31  $GBGSV,5,2,18,05,40,264,,06,54,132,26,07,42,177,29,08,28,020,37,3*77\n",
            "03:52:31  $GBGSV,5,3,18,09,43,169,,10,55,209,24,13,33,352,39,16,53,145,26,3*7E\n",
            "03:52:31  $GBGSV,5,4,18,18,37,350,,20,16,216,,23,08,156,,27,38,003,,3*71\n",
            "03:52:31  $GBGSV,5,5,18,28,37,072,,30,04,321,,3*71\n",
            "03:52:31  $GNGLL,0641.64673,N,10137.05675,E,035231.00,A,A*77\n",
            "03:52:31  $PUBX,00,035231.00,0641.64673,N,10137.05675,E,19.144,G3,1.2,2.2,0.015,0.00,0.037,,0.51,0.93,0.58,26,0,0*6D\n",
            "03:52:31  $PUBX,03,32,2,U,352,30,41,064,5,U,295,67,38,064,6,U,039,18,28,064,9,e,049,03,,000,12,U,295,44,46,064,13,U,171,32,31,061,15,U,204,12,32,064,17,U,106,34,31,007,19,U,089,43,27,003,24,-,235,06,,000,25,-,315,08,,000,28,e,154,06,,000,30,-,123,-2,,000,211,e,165,14,18,000,214,U,180,53,30,020,219,-,208,07,,000,221,-,307,05,,000,222,U,354,29,41,064,229,U,068,52,24,000,234,U,280,29,43,064,236,e,093,00,,000,241,U,214,40,28,026,243,U,051,26,30,064,159,-,099,45,,000,160,-,253,68,,000,161,-,122,77,,000,162,-,094,23,,000,163,-,264,40,,000,33,e,132,54,10,000,34,U,177,42,30,020,35,U,020,28,30,064,36,e,169,43,,000*38\n" ,
            "03:52:31  $PUBX,04,035231.00,140919,532351.00,2070,18,541289,165.421,08*1A\n",
            "$GNVTG,,T,,M,0.206,N,0.382,K,A*30\n",
            ex1,
	    "$GNRMC,095520.00,A,2733.35607,S,15302.15703,E,0.042,,240719,,,A,V*0A\n",
	];

	for instr in inputs {
	    println!("instr0: {instr}");
            let bb = instr.as_bytes();
            let parsed_pkts = queue_and_parse(&mut params, &mut parser, bb).unwrap();
            println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
	}
	
	println!("params state: {:?}", params);
	println!("parser state: {:?}", parser);
	

	assert_eq!(2, params.get("GN_GGA_count").unwrap().as_number().unwrap().as_u64().unwrap()) ;
	assert_eq!(2, params.get("GN_RMC_count").unwrap().as_number().unwrap().as_u64().unwrap());
        assert_eq!(8, params.get("GA_GSV_count").unwrap().as_number().unwrap().as_u64().unwrap());
	
        //println!("n_sats_in_view: {}", );
	println!("n_sats_used: {:?}", parser.num_of_fix_satellites);
	assert_eq!(12, params["n_sats_used"].as_u64().unwrap());

	assert_eq!(11, params["GP_n_sats_used"].as_u64().unwrap());
	assert_eq!(12, params["GP_n_sats_in_view"].as_u64().unwrap());

	assert_eq!(5, params["GL_n_sats_used"].as_u64().unwrap());
	assert_eq!(10, params["GL_n_sats_in_view"].as_u64().unwrap());

	assert_eq!(6, params["GA_n_sats_used"].as_u64().unwrap());
	assert_eq!(10, params["GA_n_sats_in_view"].as_u64().unwrap());

	assert_eq!(9, params["GB_n_sats_used"].as_u64().unwrap());
	assert_eq!(18, params["GB_n_sats_in_view"].as_u64().unwrap());

	println!("UBX_POSITION_numSvs: {}", params["UBX_POSITION_numSvs"]);
	assert_eq!(26, params["UBX_POSITION_numSvs"].as_str().unwrap().parse::<i32>().unwrap());

	let plist = ["lat", "lon", "alt", "geoidal_height",  "ellipsoidal_height"];
	for pi in plist.iter() {
	    let k = &format!("{}", pi);
	    println!("k: {k}");
            println!("{}: {}", pi, params[k]);
	}

	assert!(params["lat"].as_f64().unwrap() == -27.5559345);
	assert!(params["lon"].as_f64().unwrap() == 153.0359505);
	
    }

    #[test]
    fn test_nmea_pkt_parse()
    {
	let mut params_state: HashMap<String, Value> = HashMap::new();
	let mut parser_state: Nmea = Nmea::default();
	
	//GA-GSV
	let nmea = "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73\n".to_string();
	let bb = nmea.as_bytes();
	queue_and_parse(&mut params_state, &mut parser_state, bb).unwrap();
	let parsed_pkts = queue_and_parse(&mut params_state, &mut parser_state, bb).unwrap();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
	assert_eq!(parsed_pkts.len(), 1);
	assert_eq!(
            parsed_pkts[0],
            json!({
		"type": "nmea",
		"talker": "GA",
		"name": "GSV",
		"nmea": "$GAGSV,2,1,07,02,28,068,28,07,04,307,21,13,16,327,29,15,68,339,,0*73"
            })
	);

	let s = concat!(
	    "�b\u{1}0\u{4}\u{1}�e�\u{11}\u{15}\u{4}\u{0}\u{0}\n",
	    "\u{2}\n",
	    "\u{7}\" \u{1F}Z\u{1}W���\u{3}\u{6}\n",
	    "\u{7}\"?,\u{0}����\u{8}\u{C}\n",
	    "\u{7} \n",
	    "�\u{0}����\u{4}\n",
	    "\n",
	    "\u{7}\u{1B}\u{14}D\u{1}\u{15}���\u{0}\u{F}\n",
	    "\u{7}\"\u{E}\u{1F}\u{1}����\u{1}\u{11}\n",
	    "\u{7}&.�\u{0}����\u{7}\u{13}\n",
	    "\u{4}\u{14}=�\u{0}L���\u{E}\u{18}\n",
	    "\u{7}\u{1D}\"�\u{0}�\u{3}\u{0}\u{0}\u{2}\u{1C}\n",
	    "\u{7}\u{1F}\u{1C}a\u{0}U���\u{11}\u{1E}\n",
	    "\u{7}\u{1A}\u{B} \u{0}�\u{2}\u{0}\u{0}\u{B}�\n",
	    "\u{7}\u{1C}\u{1C}D\u{0}�\u{7}\u{0}\u{0}\n",
	    "�\u{C}\u{4}\u{14}\u{4}3\u{1}z\u{3}\u{0}\u{0}\t�\n",
	    "\u{7}\u{1D}\u{10}G\u{1}!\u{1}\u{0}\u{0}\u{C}�\u{10}\u{1}\u{0}�\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}��\u{C}\u{0}\u{0}DS\u{1}\u{0}\u{0}\u{0}\u{0}\u{6}�\n",
	    "\u{7}\u{1F}%�\u{0}.\u{0}\u{0}\u{0}\u{F}�\n",
	    "\u{7}$D�\u{0}A\u{0}\u{0}\u{0}��\u{4}\u{0}\u{0}\u{4}�\u{0}\u{0}\u{0}\u{0}\u{0}\u{12}�\u{4}\u{4}\u{10}\u{C}[...\n",
	    "$GNRMC,095520.00,A,2733.35607,S,15302.15703,E,0.042,,240719,,,A,V*0A\n"
	);
	let bb = s.as_bytes();
	let parsed_pkts = queue_and_parse(&mut params_state, &mut parser_state, bb).unwrap();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
	assert_eq!(parsed_pkts.len(), 1);
	assert_eq!(
            parsed_pkts[0].get("name").unwrap().as_str().unwrap(),
	    "RMC"
	);
    }

    #[test]
    fn test_talker_gp_badelf_gps_pro_plus()
    {
	let mut params_state: HashMap<String, Value> = HashMap::new();
	let mut parser_state: Nmea = Nmea::default();
	
	let nmea = "$GPRMC,074955.000,A,0641.0037,N,10139.4031,E,0.14,118.40,101223,,,D*60\n".to_string();
	let bb = nmea.as_bytes();
	queue_and_parse(&mut params_state, &mut parser_state, bb).unwrap();
	let parsed_pkts = queue_and_parse(&mut params_state, &mut parser_state, bb).unwrap();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
	println!("pm: {}", serde_json::to_string_pretty(&params_state).unwrap());
	assert_eq!(params_state["lat"], 6.683395);
	assert_eq!(params_state["lon"], 101.65671833333333);
	assert_eq!(params_state["GP_rmc_ts"], 1702194595000u64);
		
    }

    #[test]
    fn test_talker_gn_case()
    {
	let mut params_state: HashMap<String, Value> = HashMap::new();
	let mut parser_state: Nmea = Nmea::default();
	

	let mut parsed_pkts = queue_and_parse(&mut params_state, &mut parser_state, "$GNGSA,A,3,26,31,10,32,14,16,25,20,18,22,41,,1.34,0.74,1.12*16\n".as_bytes()).unwrap();
	parsed_pkts = queue_and_parse(&mut params_state, &mut parser_state, "$GNGSA,A,3,73,80,70,,,,,,,,,,1.34,0.74,1.12*10\n".as_bytes()).unwrap();
	parsed_pkts = queue_and_parse(&mut params_state, &mut parser_state, "$GNRMC,020125.00,A,1845.82207,N,09859.94984,E,0.027,,101219,,,F,V*1A\n".as_bytes()).unwrap();
	println!("parsed_json: {}", serde_json::to_string_pretty(&parsed_pkts).unwrap());
	println!("pm: {}", serde_json::to_string_pretty(&params_state).unwrap());
	assert_eq!(params_state["lat"], 18.763701166666667);
	assert_eq!(params_state["lon"], 98.999164);
		
    }
}
