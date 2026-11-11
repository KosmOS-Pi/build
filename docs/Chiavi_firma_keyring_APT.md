# KosmOS – Chiavi di firma e keyring APT

Riferimento su come funzionano le chiavi GPG del repository APT di KosmOS: ruoli, file e posizioni, contenuto dei pacchetti `kosmos-archive-keyring` e `kosmos-apt-config`, comandi `gpg`, fingerprint da pubblicare, procedure di rotazione e revoca. Qui stanno **definizioni e procedure**. Le decisioni stanno in «Decisioni e convenzioni» (§2.10), le cose da fare e da collaudare nel TODO.

Legenda dei comandi e delle procedure:

- **[provato]**: eseguito con successo.
- **[a memoria]**: scritto senza averlo eseguito; da collaudare prima di fidarsene (l'elenco dei collaudi è nel TODO).

## 1. Come funziona

- `reprepro` genera per ogni codename firmato i file `Release`, `InRelease` (firma in chiaro) e `Release.gpg` (firma staccata). `apt` usa `InRelease`.
- I `.deb` non sono firmati uno per uno. La fiducia scende a cascata: la firma copre `Release`, che contiene gli hash di `Packages`, che contiene gli hash dei `.deb`.
- Lato utente `Signed-By` nel file `.sources` è il **percorso di un file** con la chiave pubblica. Apt accetta la firma se proviene da una chiave contenuta in quel file. Una firma fatta da una sottochiave è valida se il file contiene la primaria con quella sottochiave collegata, non scaduta e non revocata.
- Quindi il fingerprint della sottochiave non compare mai nel `.sources`. Cambiare sottochiave significa cambiare il **contenuto** del keyring, non il `.sources` e non il fingerprint della primaria.
- La chiave pubblica distribuita contiene: primaria, identità (uid), sottochiavi, firme di collegamento e le eventuali revoche. Una revoca o un cambio di scadenza raggiunge gli utenti solo con un nuovo keyring.
- Trixie verifica con `sqv`, più severo di `gpgv` (algoritmi e firme di collegamento); i workflow verificano con `gpgv`.

## 2. Le chiavi e i loro ruoli

| Chiave | Dove sta | Passphrase | Scadenza | Ruolo |
| --- | --- | --- | --- | --- |
| Primaria `[C]` | Computer personale e backup offline | Sì | Nessuna | Identità e fingerprint pubblico; certifica e revoca le sottochiavi. Mai in CI. |
| Sottochiave di firma `[S]` (ed25519), copia completa | Keyring GPG personale | Sì | Nessuna | Firma a mano se serve. |
| Copia CI della sottochiave `[S]` | Secret GitHub e backup cifrato personale | Nessuna | Nessuna | Firma `Release` nelle promozioni. |
| Sottochiave `[S]` di riserva | Solo offline | Sì | Nessuna | Sostituisce la sottochiave attiva se compromessa (§8.3). |
| Sottochiave `[E]` preesistente (se c'è) | Keyring personale | Sì | | Non usata dal repository. Viene esportata nella chiave pubblica ed è innocua. |

Chi firma cosa: `trixie` e `trixie-old` sono firmati con la sottochiave attiva; `trixie-testing` no (nessun `SignWith`, usato solo con `Trusted: yes`). La build in `testing` non usa mai la chiave: solo la promozione, che cambia i suite firmati, la richiede.

Le due sottochiavi di firma sono identiche: annotare subito quale è quella della CI e quale la riserva. La riserva non va mai esportata verso la CI.

## 3. File e posizioni

### 3.1 Computer personale

- `~/.gnupg/`: il keyring vero, con la primaria e le due sottochiavi di firma (CI e riserva).
- Backup offline cifrato dell'export completo (`gpg --export-secret-keys --armor <FP_PRIMARIA>`), in due copie in luoghi diversi.
- Backup su carta della chiave completa, ancora protetta dalla passphrase, in due forme (`paperkey` e QR armored): vedi §5.7.
- `kosmos-primary-revoke.asc`: certificato di revoca della primaria, generato una volta e conservato offline.
- `kosmos-archive-keyring.pgp`: chiave pubblica binaria, la stessa che finisce nel pacchetto.
- `kosmos.gpg.asc` (chiave vecchia): resta quello per gli utenti bookworm e non va sostituito con la chiave nuova.
- File temporanei, da cancellare dopo l'uso con `shred -u`: `ci-signing-subkey-nopass.asc`, `/dev/shm/full.asc`; le cartelle `/dev/shm/gnupg-tmp` e `/dev/shm/gnupg-test` (tutte in memoria) si cancellano con `rm -rf`.

### 3.2 GitHub (repo `KosmOS-Pi/build`)

- Secret `APT_SIGNING_KEY`: contenuto di `ci-signing-subkey-nopass.asc`, salvato come secret **dell'Environment** `apt-signing`. Lo vede solo il job che dichiara `environment: apt-signing`. Non deve esistere un secret omonimo a livello di repository.
- Secret SFTP (`SFTP_HOST`, `SFTP_USER`, `SFTP_PASSWORD`, `SFTP_KNOWN_HOSTS`): non riguardano le chiavi di firma.
- `test-signing.yml` (solo `workflow_dispatch`, input: fingerprint della sottochiave): importa il secret in un `GNUPGHOME` temporaneo, controlla che la primaria sia assente (`sec#`), firma senza passphrase e verifica la firma. Non scrive sul repo APT.
- `promote.yml`, job `promote`: controlla il keyring contro il `.fpr`, legge da `conf/distributions` il valore di `SignWith` (deve essere **40 caratteri esadecimali maiuscoli**, senza `!`), importa il secret in un `GNUPGHOME` temporaneo con le stesse verifiche, esegue `reprepro --gnupghome <cartella> export trixie trixie-old`, verifica con `gpgv` contro il keyring pubblicato e cancella la cartella alla fine.
- Il fingerprint della sottochiave non è un segreto: sta in `conf/distributions`.

### 3.3 Server (`https://deb.kosmos-pi.org/`)

- `<distro>/conf/distributions`: `SignWith` per `trixie` e `trixie-old`, nessuno per `trixie-testing`. Non leggibile via HTTP.
- `<distro>/dists/<codename>/Release`, `InRelease`, `Release.gpg`: generati da `reprepro`, pubblici.
- `keys/kosmos.gpg.asc`: chiave per gli utenti bookworm. Finché il repo bookworm è firmato con la chiave vecchia non cambia nulla.
- `keys/kosmos-archive-keyring.pgp` e `keys/kosmos-archive-keyring.asc`: copia binaria identica a quella del pacchetto e copia armored.

### 3.4 Repo `pi-gen` (ramo `kosmos-trixie`)

Il ramo contiene i file in `stage2/99-kosmos-setup/files/`:

- `kosmos-bootstrap.pgp`: copia della chiave pubblica dei pacchetti. Non serve solo al bootstrap dell'immagine: lo leggono anche `build-package.yml` (keyring per le build-dependency, installato come `kosmos-build-keyring.pgp`) e `promote.yml` (verifica con `gpgv`). **Va quindi aggiornato a ogni modifica della chiave pubblica, prima di firmare con una sottochiave nuova.**
- `kosmos-archive-keyring.fpr`: una riga, fingerprint della primaria, 40 caratteri senza spazi. Confrontato col `.pgp` dai workflow. Il file e il keyring stanno nello stesso repo: il controllo protegge dagli errori, non da un attacco; la protezione vera è il confronto con i canali di §7.
- `kosmos-bootstrap.sources`: file provvisorio con `Signed-By` verso `/usr/share/keyrings/kosmos-bootstrap.pgp`.

Il keyring esiste quindi in **tre copie** (pacchetto, `pi-gen`, `keys/` sul server) che devono restare identiche.

### 3.5 Immagine

`stage2/99-kosmos-setup/00-run.sh`, in chroot:

1. copia `kosmos-bootstrap.pgp` in `/usr/share/keyrings/` e `kosmos-bootstrap.sources` in `/etc/apt/sources.list.d/`;
2. `apt update && apt install -y kosmos-archive-keyring kosmos-apt-config`, così apt verifica davvero la firma;
3. cancella i due file provvisori (altrimenti doppio `Signed-By`).

Dopo il bootstrap `kosmos-apt-config` installa `kosmos.sources`. `kosmos-setup.sh` non tocca il repo.

### 3.6 Sistema installato

- Trixie: `/usr/share/keyrings/kosmos-archive-keyring.pgp` e `/etc/apt/sources.list.d/kosmos.sources`.
- Bookworm (sistemi esistenti, non toccati): `/etc/apt/sources.list.d/kosmos.list` e `/etc/apt/keyrings/kosmos.gpg.asc`.

## 4. I pacchetti

Entrambi sono pacchetti `kosmos-*`: formato `3.0 (quilt)`, `Architecture: all`, `debian/rules` ridotto a `dh $@`, versione `<X.Y>-<N>~deb13` (esempio `1.0-1~deb13`), senza `+kosmos` e senza epoch.

**kosmos-archive-keyring**

- Contenuto: `kosmos-archive-keyring.pgp` installato in `/usr/share/keyrings/` con `debian/install`.
- Nessuna dipendenza oltre a `${misc:Depends}`.
- Va ripubblicato ogni volta che cambia la chiave pubblica: nuova sottochiave, revoca, modifica della scadenza. In questi casi cambia `<X.Y>`; una correzione di solo packaging cambia `<N>`.

**kosmos-apt-config**

- Contenuto: `/etc/apt/sources.list.d/kosmos.sources`.
- Dipende da `kosmos-archive-keyring`, con versione minima quando una rotazione la richiede.
- Il file in `/etc` è un conffile (lo gestisce `debhelper`): le modifiche dell'utente, per esempio disattivare `old`, sopravvivono agli aggiornamenti.

Il file `.sources`:

```
Types: deb
URIs: https://deb.kosmos-pi.org/trixie/
Suites: trixie trixie-old
Components: main
Architectures: arm64
Signed-By: /usr/share/keyrings/kosmos-archive-keyring.pgp
```

Collaudo di un pacchetto: installarlo su una VM trixie pulita, `apt update` senza avvisi, `apt-cache policy` che mostra le due suite.

## 5. Comandi gpg

Sostituire `<FP_PRIMARIA>` e `<FP_SUB>` con i fingerprint (40 caratteri esadecimali, senza spazi).

### 5.1 Creazione delle chiavi [provato]

Una volta sola, sul computer personale, mai in CI. Scadenza zero, passphrase robusta chiesta dal pinentry. Per nome e indirizzo dell'identità usare quelli da pubblicare: finiscono nella chiave pubblica distribuita agli utenti.

```bash
# 1. Chiave primaria ed25519, solo certificazione [C], senza scadenza
gpg --quick-generate-key 'KosmOS Archive Signing Key <indirizzo@dominio>' ed25519 cert 0

# 2. Leggi il fingerprint della primaria (riga sotto 'sec')
gpg --list-secret-keys --keyid-format long

# 3. SUBITO: certificato di revoca, da tenere offline
gpg --output kosmos-primary-revoke.asc --gen-revoke <FP_PRIMARIA>

# 4. SUBITO: backup completo della chiave segreta, da cifrare e tenere offline in due copie
gpg --export-secret-keys --armor <FP_PRIMARIA> > kosmos-primary-backup.asc

# 5. Sottochiave di firma per la CI, senza scadenza (0)
gpg --quick-add-key <FP_PRIMARIA> ed25519 sign 0

# 6. Sottochiave di firma di riserva, da tenere solo offline
gpg --quick-add-key <FP_PRIMARIA> ed25519 sign 0

# 7. Fingerprint delle due sottochiavi: annotali e distinguile (CI / riserva)
gpg --list-secret-keys --keyid-format long --with-subkey-fingerprints
```

Con una chiave nuova il fingerprint della primaria cambia: il repo bookworm, firmato con la chiave vecchia, non va rifirmato con questa, altrimenti gli utenti bookworm (che hanno `kosmos.gpg.asc` con la chiave vecchia) non riescono più ad aggiornare.

Controllo: con `gpg -K` non deve comparire nessun `[expires: ...]` su primaria e sottochiavi.

### 5.2 Fingerprint ed export della chiave pubblica [provato]

```bash
# Solo il fingerprint della primaria, senza spazi
gpg --list-secret-keys --with-colons | awk -F: '$1=="fpr"{print $10; exit}'

# Esporta la chiave pubblica per gli utenti (binaria, per il pacchetto)
gpg --export --export-options export-minimal <FP_PRIMARIA> > kosmos-archive-keyring.pgp

# Stessa chiave in formato armored
gpg --export --armor --export-options export-minimal <FP_PRIMARIA> > kosmos.gpg.asc

# Contenuto di un file keyring, con tutti i fingerprint
gpg --show-keys --with-fingerprint --with-subkey-fingerprints kosmos-archive-keyring.pgp

# Verifica una firma e quale chiave ha firmato
gpg --no-default-keyring --keyring ./kosmos-archive-keyring.pgp --verify --verbose InRelease
```

### 5.3 Copia della sottochiave per la CI, senza passphrase [provato]

`passwd` non funziona su un keyring che contiene solo la sottochiave (`sec#`, errore «Nessuna chiave segreta»): la primaria deve esserci. Si importa quindi la chiave completa in un keyring temporaneo in memoria, si toglie la passphrase lì, si esporta solo la sottochiave attiva e si distrugge il keyring temporaneo. Il keyring vero non viene toccato. La passphrase viene chiesta anche all'import della sottochiave: è normale, ha la stessa passphrase della primaria.

```bash
# 1. Export del keyring vero (chiede la passphrase) in un file temporaneo in memoria
umask 077
gpg --export-secret-keys --armor <FP_PRIMARIA> > /dev/shm/full.asc

# 2. Keyring temporaneo in memoria, import della chiave completa
mkdir -m 700 /dev/shm/gnupg-tmp
gpg --homedir /dev/shm/gnupg-tmp --import /dev/shm/full.asc

# 3. Togli la passphrase a tutto il keyring temporaneo
gpg --homedir /dev/shm/gnupg-tmp --pinentry-mode loopback --edit-key <FP_PRIMARIA>
#   gpg> passwd   (vecchia passphrase, poi nuova vuota, confermando se chiede)
#   gpg> save

# 4. Esporta la sola sottochiave di firma attiva (mai la primaria, mai la riserva)
gpg --homedir /dev/shm/gnupg-tmp --armor --export-secret-subkeys <FP_SUB>! > ci-signing-subkey-nopass.asc

# 5. Distruggi il keyring temporaneo
gpgconf --homedir /dev/shm/gnupg-tmp --kill gpg-agent
rm -rf /dev/shm/gnupg-tmp
shred -u /dev/shm/full.asc

# 6. Verifica in un keyring nuovo: deve mostrare sec# e firmare senza chiedere passphrase
mkdir -m 700 /dev/shm/gnupg-test
gpg --homedir /dev/shm/gnupg-test --import ci-signing-subkey-nopass.asc
gpg --homedir /dev/shm/gnupg-test -K
echo prova | gpg --homedir /dev/shm/gnupg-test --batch --pinentry-mode error --local-user <FP_SUB>! --clearsign
```

Dopo aver salvato il file come secret `APT_SIGNING_KEY`, cancellare `ci-signing-subkey-nopass.asc` con `shred -u` e il keyring di verifica. Il workflow `test-signing` ripete la verifica lato GitHub.

### 5.4 Scadenza [a memoria]

```bash
# Primaria senza scadenza
gpg --quick-set-expire <FP_PRIMARIA> 0
# Sottochiave senza scadenza
gpg --quick-set-expire <FP_PRIMARIA> 0 <FP_SUB>
```

Se una sottochiave fosse stata creata con una scadenza (per esempio `3y`), la copia CI la porta dentro la propria firma di collegamento: per toglierla si usa `--quick-set-expire`, poi si riesportano la chiave pubblica **e** la copia CI, si ricarica il secret e si ripubblica il keyring.

### 5.5 Revoca [a memoria]

```bash
# Certificato di revoca della primaria (generato alla creazione, §5.1)
gpg --output kosmos-primary-revoke.asc --gen-revoke <FP_PRIMARIA>

# Revoca di una sottochiave: key N seleziona la sottochiave, revkey la revoca
gpg --edit-key <FP_PRIMARIA>
#   gpg> key 2
#   gpg> revkey
#   gpg> save
```

### 5.6 Firma con `reprepro` [provato]

`reprepro` accetta in `conf/distributions` il fingerprint della sottochiave **senza** `!` e firma con la sola sottochiave, senza la primaria. Nel workflow: `reprepro -b work --gnupghome "$GNUPGHOME" export trixie trixie-old` (§3.2).

### 5.7 Backup su carta [provato, manca la firma di prova]

Copia su carta della chiave segreta **completa** (primaria e le due sottochiavi di firma, CI e riserva), ancora protetta dalla passphrase. Quattro script in `build/scripts/`, tutti con prefisso `key-`, in due forme complementari:

- `key-paper-backup.sh <FP_PRIMARIA> [cartella]`: usa `paperkey`; produce `paper.txt` (testo breve da stampare), `paper-qr.png` (un solo QR, corpo senza intestazione) e `public.pgp`. Ripristino: `key-paper-restore.sh <paper.txt|immagine QR> <public.pgp> [FP_PRIMARIA]`, che richiede la chiave pubblica.
- `key-qr-backup.sh <FP_PRIMARIA> [cartella]`: export armored completo, spezzato per righe intere in più QR (`LINES_PER_QR`, default 10, correzione d'errore H, riga `KOSMOS-QR i/n` in testa a ciascuno); produce `qr-NN-of-NN.png`, `secret-armored.asc` (stesso contenuto in testo) e `public.asc`. Ripristino: `key-qr-restore.sh [-o file] [-f FP_PRIMARIA] <file>...`, con le parti in qualunque ordine; segnala quelle mancanti.

Tutti gli script rispettano `GNUPGHOME` e lavorano in `/dev/shm`. Alla fine di ogni backup verificano da soli che i QR si decodifichino e che un ripristino in un keyring temporaneo dia gli stessi fingerprint.

```bash
# Backup (chiede la passphrase)
scripts/key-paper-backup.sh <FP_PRIMARIA>
scripts/key-qr-backup.sh <FP_PRIMARIA>

# Ripristino in un keyring nuovo
GNUPGHOME=/dev/shm/gnupg-nuovo scripts/key-paper-restore.sh paper-qr.png public.pgp <FP_PRIMARIA>
GNUPGHOME=/dev/shm/gnupg-nuovo scripts/key-qr-restore.sh -f <FP_PRIMARIA> qr-*.png

# Prova della passphrase sulla chiave ripristinata (deve chiederla e dare "Good signature")
echo test | GNUPGHOME=/dev/shm/gnupg-nuovo gpg --local-user <FP_SUB>! --clearsign
```

Regole:

- Non partire mai dalla copia CI senza passphrase (`ci-signing-subkey-nopass.asc`): non va mai stampata.
- La passphrase non va sullo stesso foglio né nello stesso luogo.
- Sul foglio annotare anche il fingerprint della primaria e quale sottochiave è CI e quale riserva; stampare anche `kosmos-primary-revoke.asc`.
- Stampa in locale, senza code di stampa di rete o cloud; due copie in luoghi diversi.
- I file prodotti stanno in `/dev/shm`: dopo la stampa `shred -u <cartella>/*` e `rmdir`.
- Il ripristino con `paperkey` usa il `public.pgp` prodotto dal backup; il keyring pubblicato non è stato provato come sostituto.

## 6. Fingerprint: quali e dove pubblicarli

**Quali**

- Il fingerprint **completo** (40 caratteri) della chiave **primaria**, a gruppi di quattro. È l'ancora di fiducia: non cambia con le rotazioni delle sottochiavi.
- Facoltativo, a titolo informativo: uno storico delle sottochiavi (fingerprint, data, stato attiva o revocata). Non serve all'utente per verificare.
- Mai solo l'ID corto della chiave: si può falsificare.

**Dove**, su più canali indipendenti, perché chi controlla l'hosting `deb.kosmos-pi.org` controlla sia i `.deb` sia la chiave, quindi un solo canale non basta:

1. pagina di installazione di https://kosmos-pi.org;
2. README del repository `build`, o dell'organization GitHub (la cronologia git rende le modifiche visibili);
3. repo `pi-gen`: file `kosmos-archive-keyring.fpr`;
4. facoltativo: un keyserver (keys.openpgp.org); mostra l'identità solo dopo la verifica dell'e-mail.

**Come verifica l'utente**: scarica il keyring (o estrae il `.deb`), lancia `gpg --show-keys --with-fingerprint <file>`, poi confronta il fingerprint con almeno due canali.

## 7. Rotazione e revoca

### 7.1 Casi

| Evento | Cambia il fingerprint della primaria | Serve un nuovo keyring agli utenti |
| --- | --- | --- |
| Sostituzione del secret in GitHub (stessa sottochiave) | No | No |
| Rotazione ordinaria della sottochiave | No | Sì, **prima** di usare la nuova |
| Sottochiave compromessa | No | Sì, urgente |
| Primaria compromessa o persa | Sì | Sì, a mano |

### 7.2 Rotazione ordinaria (ordine obbligatorio)

1. Creare la nuova sottochiave `[S]` senza scadenza (§5.1, passo 5) e riesportare la chiave pubblica: ora contiene vecchia e nuova sottochiave.
2. Aggiornare `kosmos-bootstrap.pgp` nel ramo `kosmos-trixie` di `pi-gen` e `keys/` sul server: lo leggono build e promozione, quindi deve contenere la sottochiave nuova **prima** di firmare con essa, altrimenti la verifica `gpgv` di `promote` fallisce.
3. Pubblicare un nuovo `kosmos-archive-keyring` (nuovo `<X.Y>`), ancora firmato con la vecchia sottochiave, e lasciarlo arrivare agli utenti con un normale `apt upgrade`. Attendere un tempo ragionevole (da decidere: vedi «Decisioni da prendere» nel TODO).
4. Solo dopo: nuovo secret in GitHub (§5.3) e nuovo fingerprint in `conf/distributions`; rifirmare tutti i codename firmati (`reprepro export <codename>` per ciascuno, in pratica una promozione).
5. Revocare la vecchia sottochiave, riesportare, pubblicare un keyring con la revoca; aggiornare di nuovo `kosmos-bootstrap.pgp`, `keys/` e l'eventuale storico sul sito.
6. Cancellare il vecchio secret e i file temporanei.

Se si firma con la sottochiave nuova prima che gli utenti abbiano il keyring aggiornato, il loro `apt update` fallisce.

### 7.3 Sottochiave compromessa (e perché serve una riserva)

Se il secret in CI viene rubato, bisogna revocare la sottochiave. Ma gli utenti ricevono la revoca solo con un nuovo keyring, e per scaricarlo devono prima fidarsi della firma del repo.

- **Senza sottochiave di riserva**: la nuova sottochiave non è nei keyring degli utenti. Finché non installano il nuovo keyring a mano, `apt update` fallisce con errore di firma.
- **Con una sottochiave di riserva già inclusa** nel keyring pubblicato fin dall'inizio, tenuta solo offline: si revoca quella compromessa, si mette la riserva in CI e in `conf/distributions`, si rifirma. Gli utenti la accettano subito perché è già nel loro keyring, e con il successivo `apt upgrade` ricevono anche la revoca.

Finché la revoca non arriva, chi ha rubato il secret può firmare solo se riesce anche a servire un repo falso agli utenti (controllo dell'hosting o attacco sulla rete): per questo la revoca va pubblicata rapidamente.

Procedura:

1. Rimuovere subito il secret da GitHub.
2. Revocare la sottochiave compromessa (§5.5).
3. Attivare la riserva (o creare una nuova sottochiave): copia CI senza passphrase (§5.3), nuovo secret e nuovo fingerprint in `conf/distributions`; rifirmare.
4. Pubblicare il nuovo keyring con la revoca (pacchetto, `pi-gen`, `keys/`).
5. Aggiornare sito e canali di §6 se serve, e pubblicare un avviso.

### 7.4 Primaria compromessa o persa

- Se è compromessa: pubblicare il certificato di revoca (`kosmos-primary-revoke.asc`) e creare una chiave nuova (§5.1). Cambiano il fingerprint, il keyring e tutte le pagine che lo pubblicano.
- Gli utenti dovranno installare a mano il nuovo keyring da un canale indipendente, e fino ad allora `apt update` fallisce.
- Se la primaria è persa ma non compromessa, senza il suo certificato di revoca non si può revocare nulla: per questo il certificato e il backup offline sono essenziali.

### 7.5 Chiavi senza scadenza

Il rischio è che una chiave compromessa e non notata resti valida finché non la si revoca. Le difese sono il certificato di revoca, il backup, la separazione primaria e sottochiave e la riserva. A ogni nuova Debian va riprovato `apt update` con il keyring, perché le politiche di `sqv` possono diventare più severe sugli algoritmi.

### 7.6 Controllo dopo ogni rotazione

- `gpg --show-keys --with-fingerprint --with-subkey-fingerprints` sul keyring nuovo: primaria uguale a prima, sottochiavi attese, revoche presenti.
- `apt update` pulito su una VM trixie con un keyring vecchio (prima del passo di cambio) e uno nuovo.
- Build dell'immagine e un run di `promote.yml` con il file di bootstrap aggiornato.
- Fingerprint della primaria immutato su tutti i canali di §6.
- Le tre copie del keyring identiche (§3.4).
