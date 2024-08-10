| SIP-Number          | 21                                        |
| ---:                |:-----------------------------------------------------------------------------------------------|
| Title               | Store keypairs with aes-128 encryption                                                         |
| Description         | Currently Sui store keypair in file only using base64 which should using aes-128 encode better |
| Author              | oday0311@hotmail.com                                                                           |
| Editor              | Alex Tsiliris <alex.tsiliris@sui.io, @Eis-D-Z>                                                 |
| Type                | Standard                                                                                       |
| Category            | Core                                                                                           |
| Created             | 2024-05-03                                                                                     |
| Comments-URI        | https://sips.sui.io/comments-21                                                                |
| Status              | Draft                                                                                          |
| Requires            | -                                                                                              |

## Abstract

Sui currently store keypairs in files[sui.keystore,network.yaml,fullnode.yaml] only using base64 which should using aes-128 encode better.

## Motivation

base64 is not secure enough to store keypair in files, it should use aes-128 encode better.
there are some cases, we don't want to display the base64 directly in the files,
by add the default aes-encode, developers can compile the bin files with their own encrypt password, 
so instead of save base64 content , I think aes-encode content with user-custom aes-128 result is more reasonable. 
in fact, similar cases exist in the config files, network.yaml, fullnode.yaml, all the key-pair currently only save as base-64,
but key-pairs content is less used in normal developer, but cli-key tool is widly use for 
dapps developers in their server for deploy dapps.

## Specification
1. for keystore files, we should add a step before we save base64 content to files,
   FileBasedKeystore
         //add aes-128-cbc default encryption
         let encode_data = default_des_128_encode(store.as_bytes());
         fs::write(path, encode_data)?;
   and before new from files, keystore shoud try to decode from des-128:
           if contents.starts_with("[") {
                kp_strings = serde_json::from_str(&*contents)
             .map_err(|e| anyhow!("Can't deserialize FileBasedKeystore from {:?}: {e}", path))?;
            }else {
                let decode_data = default_des_128_decode(contents);
                kp_strings = serde_json::from_str(&*decode_data)
                    .map_err(|e| anyhow!("Can't deserialize FileBasedKeystore from {:?}: {e}", path))?;
            }
2. for fullnode.yaml , network.yaml files, we should change the serder function
   #[serde(default = "default_authority_key_pair")]
   #[serde(serialize_with = "serialize_with_aes_encode_authoritykey")]
   #[serde(deserialize_with = "deserialize_with_aes_encode_authoritykey")]
   pub protocol_key_pair: AuthorityKeyPairWithPath,

   #[serde(default = "default_key_pair")]
   #[serde(serialize_with = "serialize_with_aes_encode")]
   #[serde(deserialize_with = "deserialize_with_aes_encode")]
   pub worker_key_pair: KeyPairWithPath,
   #[serde(default = "default_key_pair")]
   #[serde(serialize_with = "serialize_with_aes_encode")]
   #[serde(deserialize_with = "deserialize_with_aes_encode")]
   pub account_key_pair: KeyPairWithPath,
   #[serde(default = "default_key_pair")]
   #[serde(serialize_with = "serialize_with_aes_encode")]
   #[serde(deserialize_with = "deserialize_with_aes_encode")]
   pub network_key_pair: KeyPairWithPath,
 
  the deserialize_with_aes_encode_xxx is a little complex, for we need to support both string and mapping type,
  fn deserialize_with_aes_encode_authoritykey<'de, D>(deserializer: D) -> Result<AuthorityKeyPairWithPath, D::Error>
  where
  D: Deserializer<'de>,
  {
  let value: serde_yaml::Value = match serde_yaml::Value::deserialize(deserializer) {
  Ok(value) => value,
  Err(_) => return Err(D::Error::custom("Failed to deserialize value as YAML")),
  };

    match value {
        serde_yaml::Value::String(mut s) => {
            if s.starts_with(DEFAULT_AES_PREFIX) {
                s = node_des_128_decode(s);
            }
            let keypair  = <AuthorityKeyPair as EncodeDecodeBase64>::decode_base64(&s);

            Ok(AuthorityKeyPairWithPath::new(keypair.unwrap()))
        }
        serde_yaml::Value::Mapping(map) => {
            let path = map.get(&Value::String("path".parse().unwrap())).ok_or_else(|| D::Error::custom("Missing path"))?;
            println!("path: {:?}", path);
            let keypair = read_authority_keypair_from_file(path.as_str().unwrap()).map_err(|e| D::Error::custom(format!("Failed to read keypair from file: {}", e)))?;
            Ok(AuthorityKeyPairWithPath::new(keypair))
        }
        _ => {
            Err(D::Error::custom("Invalid value type, expected string or mapping"))
        }
    }


}


## Rationale
1.sui.keystore files comes from FileBasedKeystore::save , it should be aes-128 encode before save to files. also add decode step before new from files.
2. for network.yaml,and fullnode.yaml, we should change the serder function to support both string and mapping type,
and add aes-128 encode/decode step before save to files and new from files.



## Backwards Compatibility

There are no issues with backwards compatability.



## Test Cases

1. rosetta test : read_prefunded_account

## Reference Implementation



## Security Considerations



## Copyright
[CC0 1.0](../LICENSE.md).

