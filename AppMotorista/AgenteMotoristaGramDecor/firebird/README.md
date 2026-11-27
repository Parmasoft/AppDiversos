# Firebird return migration

`20260925_0001_sp_apl_entrega_nuvem.sql` is deliberately a reviewed-contract
envelope, not an executable migration. The production procedure body must not
be guessed or partially copied. It remains blocked until the complete legacy
business branch has been reproduced and tested against a disposable Firebird
2.5 database. `SP_REG_ENTREGA_MANIFESTO` is never modified by this migration.
