use std::time::{SystemTime, UNIX_EPOCH};
use std::collections::{HashMap};
use serde_json::Value;

pub const TALKER_ID_ANY:&str = "ANY";
pub const SUFFIX_COUNT:&str = "count";
pub const SUFFIX_TIMESTAMP:&str = "ts";
pub const TALKER_NONE:&str = "";

pub fn get_current_time_millis() -> u64 {
    match (SystemTime::now()
           .duration_since(UNIX_EPOCH))
    {
	Ok(ts) => {
	    ts.as_millis() as u64
	}
	Err(_) => {
	    0
	}
    }
}

pub fn put_param(params: &mut HashMap<String, Value>, talker_id: String, param: String, val: Value)
{
    let key = if talker_id.is_empty() {param.clone()} else {format!("{}_{}", talker_id, param)};
    let key_any = format!("{}_{}", TALKER_ID_ANY, param);
    let key_ts = format!("{}_{}", key, SUFFIX_TIMESTAMP);
    let param_counter = format!("{}_{}", key, SUFFIX_COUNT);
    println!("put_param: {key} {val} {param_counter}");
    params.insert(key, val.clone());
    params.insert(key_any, val);
    params.insert(key_ts, Value::from(get_current_time_millis()));
    inc_param(params, TALKER_NONE.to_string(), param_counter);
}

pub fn inc_param(params_state: &mut HashMap<String, Value>, talker_id: String, param_name: String) -> u64
{
    let key = if talker_id.is_empty() {param_name.clone()} else {format!("{}_{}", talker_id, param_name)};
    match params_state.get(&key) {
	Some(val) => {
	    match (val.as_number()) {
		Some(num) => {
		    let nv = num.as_u64().unwrap()+1;
		    params_state.insert(key, Value::from(nv));
		    nv
		}
		None => {
		    let nv = 1;
		    params_state.insert(key, Value::from(nv));
		    nv
		}
	    }
	}
	None => {
	    let nv:u64 = 1u64;
	    params_state.insert(key, Value::from(nv));
	    nv
	}
    }
    
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_put_param()
    {
	let mut m:HashMap<String, Value> = HashMap::new();
	let lat = 11.000001;
	let lon = 111.000001;

	put_param(&mut m, "".to_string(), "lat".to_string(), Value::from(lat));
	print!("{:?}", m);
	assert_eq!(m.get(&("lat").to_string()).unwrap().as_f64().unwrap(), lat);
	assert_eq!(m.get(&("lat_count".to_string())).unwrap().as_number().unwrap().as_u64().unwrap(), 1);

	put_param(&mut m, "".to_string(), "lat".to_string(), Value::from(lat));
	print!("{:?}", m);
	assert_eq!(m.get(&("lat".to_string())).unwrap().as_f64().unwrap(), lat);
	assert_eq!(m.get(&("lat_count".to_string())).unwrap().as_number().unwrap().as_u64().unwrap(), 2);

	put_param(&mut m, "".to_string(), "lon".to_string(), Value::from(lon));
	print!("{:?}", m);
	assert_eq!(m.get(&("lon".to_string())).unwrap().as_f64().unwrap(), lon);
	assert_eq!(m.get(&("lon_count".to_string())).unwrap().as_number().unwrap().as_u64().unwrap(), 1);
	
    }

    #[test]
    fn test_inc_param()
    {
	let mut m:HashMap<String, Value> = HashMap::new();
	assert_eq!(1, inc_param(&mut m, "".to_string(), "counter_a".to_string()));
	assert_eq!(1, inc_param(&mut m, "".to_string(), "counter_b".to_string()));
	assert_eq!(2, inc_param(&mut m, "".to_string(), "counter_a".to_string()));
    }    
}
