"""Ferramenta administrativa de homologacao: cria sessao e exibe somente QR."""

import argparse
from datetime import datetime

import qrcode
from sqlalchemy import select

from app import create_app
from app.provisioning import (
    mobile_bootstrap_qr_payload,
    provision_temporary_mobile_session,
)
from app.database import get_engine
from app.tables import manifest_projection, tenant


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tenant-external-id", required=True)
    parser.add_argument("--manifest-guid", required=True)
    parser.add_argument("--expires-at", required=True)
    args = parser.parse_args()
    expires_at = datetime.fromisoformat(args.expires_at)
    app = create_app()
    with app.app_context():
        statement = (
            select(
                tenant.c.id,
                manifest_projection.c.driver_guid,
                manifest_projection.c.detail_json,
            )
            .select_from(
                manifest_projection.join(
                    tenant, tenant.c.id == manifest_projection.c.tenant_id
                )
            )
            .where(
                tenant.c.external_id == args.tenant_external_id,
                manifest_projection.c.manifest_guid == args.manifest_guid,
            )
        )
        with get_engine().connect() as connection:
            row = connection.execute(statement).mappings().one()
        driver_guid = row["driver_guid"].strip()
        driver_name = row["detail_json"].get("motorista", {}).get("nome", "").strip()
        if not driver_guid or not driver_name:
            raise RuntimeError("Manifesto sem motorista projetado para bootstrap")
        session_id, raw_token, refresh_token, expiry = provision_temporary_mobile_session(
            row["id"], driver_guid, expires_at
        )
        payload = mobile_bootstrap_qr_payload(
            raw_token, refresh_token, expiry, driver_guid, driver_name
        )
    print(f"SESSAO_MOBILE_ID={session_id}")
    qr = qrcode.QRCode(border=1)
    qr.add_data(payload)
    qr.make(fit=True)
    qr.print_ascii(invert=True)


if __name__ == "__main__":
    main()
