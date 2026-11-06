//Curve25519 scalar mult (RFC 7748) - ADR-0006 Phase 3.
 //Phase 0: interface stub only; returns FALSE until implemented, then must
 //pass the RFC 7748 test vectors in-system before use.

#define CURVE25519_KEY_LEN	32

Bool Curve25519(U8 *private_key,U8 *public_key)
{//In place: private_key holds the clamped scalar, public_key the point; on
 //return public_key holds the product (RFC 7748).
  return FALSE;
}
