//ChaCha20 stream cipher (RFC 8439) - ADR-0006 Phase 3.
 //Phase 0: interface stub only; returns FALSE until implemented, then must
 //pass the RFC 8439 test vectors in-system before use.

#define CHACHA20_KEY_LEN	32
#define CHACHA20_NONCE_LEN	12

Bool ChaCha20(U8 *key,U8 *nonce,I64 nonce_len,U32 counter,
 U8 *data,I64 len)
{//Encrypts or decrypts data in place (symmetric).
  return FALSE;
}
