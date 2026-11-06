//BLAKE2s hash (RFC 7693) - ADR-0006 Phase 3.
 //Phase 0: interface stub only; returns FALSE until implemented, then must
 //pass the RFC 7693 test vectors in-system before use.

#define BLAKE2S_DIGEST_LEN	32
#define BLAKE2S_KEY_MAX_LEN	32

Bool Blake2s(U8 *key,I64 key_len,U8 *in,I64 in_len,U8 *_digest)
{//_digest must be at least BLAKE2S_DIGEST_LEN bytes.
  return FALSE;
}
