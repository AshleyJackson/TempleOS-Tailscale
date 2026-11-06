//Poly1305 MAC (RFC 8439) - ADR-0006 Phase 3.
 //Phase 0: interface stub only; returns FALSE until implemented, then must
 //pass the RFC 8439 test vectors in-system before use.

#define POLY1305_KEY_LEN	32
#define POLY1305_TAG_LEN	16

Bool Poly1305(U8 *key,U8 *msg,I64 msg_len,U8 *_tag)
{//_tag must be at least POLY1305_TAG_LEN bytes.
  return FALSE;
}
