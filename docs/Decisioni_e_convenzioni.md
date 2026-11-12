# KosmOS

Documento di contesto da incollare all'inizio di una nuova chat, insieme a "TODO". 

## 1. Descrizione del progetto

Questa prima parte raccoglie le linee guida generali del progetto, e resta valida finché il progetto non cambia in modo sostanziale. Le decisioni prese stanno nei paragrafi 2.x, lo stato e i lavori in corso nel TODO.
 
### 1.1 Obiettivo
 
KosmOS è una distribuzione leggera per astrofotografia su Raspberry Pi, rigidamente basata su Raspberry Pi OS, senza software accessorio e orientata alla produzione:
 
- rilasci il più vicini possibile all'upstream;
- la versione upstream precedente all'ultima è sempre disponibile (repository `old`);
- solo arm64 (armhf escluso).
Pacchetti mantenuti: INDI core e 3rdparty, KStars, PHD2 e poco altro, più pacchetti di personalizzazione del sistema (`kosmos-*`, nomi propri che non confliggono con quelli della distro). Oggi l'uso è personale, ma l'intenzione è rilasciare il lavoro anche ad altri. Il nome KosmOS evita di far pensare a una distribuzione ufficiale Raspberry Pi.
 
### 1.2 Da dove nasce la scelta
 
Il problema iniziale: driver INDI custom (tra cui un focuser e un flatpanel) da far convivere con KStars/Ekos in flatpak. Lo snooping (`IDSnoopDevice`) funziona solo tra driver nello stesso indiserver, e anche i driver standard snoopano quelli custom (ad esempio la camera legge la posizione del focuser per il FITS). Un secondo indiserver collegato come Remote non risolve, perché lo snooping non attraversa due server separati. Soluzione adottata:
 
- un solo indiserver sulla Pi, con INDI compilato in proprio e tutti i driver (standard e custom) nello stesso server; può essere autonomo o avviato da Ekos.
- KStars compilato in proprio; in questo scenario resta comunque utilizzabile anche come semplice client in flatpak con profili Ekos "speculari" creati tramite INDI Web Manager;
- Astroberry e il PPA di Mutlaq scartati.
L'utente aveva già costruito una propria distro basata su Raspberry Pi OS bookworm con pacchetti compilati da sé quando Astroberry era fermo. Il lavoro prosegue seguendo le versioni successive di Raspberry Pi OS (oggi trixie).
 
### 1.3 Dove vive il progetto
 
- **GitHub**, organization `KosmOS-Pi`: un repository per ogni pacchetto (`dpkg-<nome>`: libxisf, stellarsolver, libindi, indi-3rdparty, kstars, driver custom, vari `kosmos-*`, ecc.), il repository `pi-gen` (personalizzazione per generare le immagini KosmOS), `wp-kosmos-notifications` e il repository centrale `build` con i workflow di CI.
- **Repository APT**: https://deb.kosmos-pi.org/, su hosting condiviso con solo accesso SFTP, senza SSH. Non si può installare `reprepro` sul server: il repository si gestisce in locale (o in CI) e si sincronizza via SFTP.
- **Sito**: https://kosmos-pi.org (WordPress), sullo stesso hosting.
### 1.4 Modello di lavoro
 
Git è la fonte di verità, GitHub Actions è l'unico a toccare l'hosting e il portale GitHub è il pannello di controllo (build, promozioni e manutenzione sono workflow lanciati da lì).
 
### 1.5 Caso particolare: indi-3rdparty
 
`dpkg-indi-3rdparty` contiene script di build (Shell) che scaricano un tag specifico di `indilib/indi-3rdparty`, il quale include sorgenti, librerie e SDK binari dei produttori. È l'unico pacchetto di questo tipo e richiede un trattamento a parte, comprese le licenze di ridistribuzione degli SDK.
 

## 2. Decisioni e convenzioni

Questa seconda parte raccoglie le regole in vigore, ciascuna con il perché in breve. Qui **non** stanno: stato dei lavori, cose da verificare, proposte (vanno nel TODO), cronaca di ciò che è stato provato (resta nella storia di git). Una voce entra solo quando una decisione viene presa o cambiata.

### 2.1. Modo di lavoro

- Conversazione in italiano; testi dei workflow (nomi di job e passi, messaggi stampati) in **inglese**.
- YAML solo con spazi, mai tabulazioni.
- Evitare di produrre codice o testo senza che sia stato richiesto, rispettando il principio base "un passo alla volta": quando la richiesta richiede una risposta lunga ed articolata, composta di molte parti diverse, presentare prima una breve sintesi e poi, quando richiesto, passare alla produzione di codice e descrizioni, ma sempre step-by-step.
- Con la stessa filosofia del punto precedente, davanti a un errore: prima un passo che stampa i fatti, poi la correzione; niente complessità sulla base di un'ipotesi.
- Si lavora solo con `git clone/push` e portale GitHub: nessuna procedura definitiva deve richiedere SSH, SFTP o GPG dal computer di lavoro, tranne in fasi transitorie di sviluppo o test, se strettamente necessario.
- Le cose non provate si dichiarano tali (molti comandi `reprepro`/`lftp`/`gpg` sono scritti a memoria).
- Ogni funzione nuova della CI si prova prima con un workflow che non scrive sul repo APT (esempi: `test-signing`, `test-sftp`, `build-image`), poi si scrive quello vero.
- Documentazione di contesto in due file: descrizione e decisioni (questo), TODO (stato). A ogni sessione si aggiorna di norma solo il TODO.
- Nella produzione di packages, evitare più possibile di installare file in percorsi di proprietà di altri pacchetti (apt blocca); `dpkg-divert` solo come ultima risorsa.

### 2.2. Piattaforma

- Solo **arm64**; `armhf` escluso. Schede supportate: Pi 4 e Pi 5 (dal catalogo imager).
- Distro attuale: **trixie** (Debian 13), da cui `deb13` nelle versioni.
- KStars è un client (flatpak o altro); il server INDI gira sulla Pi con pacchetti propri.
- Si resta su Raspberry Pi OS senza software aggiuntivo non necessario. I pacchetti Raspberry Pi (`+rpt`) non interessano.
- `libgpiod` non si gestisce più (trixie ha già la 2). `libxisf` resta pacchetto proprio.

### 2.3. Elenco dei pacchetti gestiti

Elenco completo dei repository `dpkg-<nome>`: non va mai ridotto ai soli pacchetti «da fare», altrimenti si perdono di vista. Gli stati e le note operative sono nel TODO, qui solo l'inventario e il tipo di versione.

| # | Pacchetto | Tipo | Versione |
| --- | --- | --- | --- |
| 1 | `fxload` | upstream | `+kosmos-N~deb13` |
| 2 | `libxisf` | upstream | `+kosmos-N~deb13` |
| 3 | `libindi` | upstream | `+kosmos-N~deb13` |
| 4 | `stellarsolver` | upstream | `+kosmos-N~deb13` |
| 5 | `indi-3rdparty` | upstream, caso speciale (§2.6) | `+kosmos-N~deb13` |
| 6 | `libbno08x` | upstream | `+kosmos-N~deb13` |
| 7 | `kstars` | upstream | `5:` + `+kosmos-N~deb13` |
| 8 | `python3-indi-client` | upstream | `+kosmos-N~deb13` |
| 9 | `gsc` | upstream | `+kosmos-N~deb13` |
| 10 | `phd2` | upstream | `+kosmos-N~deb13` |
| 11 | `phdlogview` | upstream | `+kosmos-N~deb13` |
| 12 | `gotify` | da chiarire | – |
| 13 | `kosmos-archive-keyring` | kosmos-*, `all` | `X.Y-N~deb13` |
| 14 | `kosmos-apt-config` | kosmos-*, `all` | `X.Y-N~deb13` |
| 15 | `kosmos-plasma-theme` | kosmos-* | `X.Y-N~deb13` |
| 16 | `kosmos-notifications` | kosmos-*, `all` | `X.Y-N~deb13` |
| 17 | `kosmos-desktop-defaults` | kosmos-* | `X.Y-N~deb13` |
| 18 | `kosmos-desktop` | kosmos-*, meta | `X.Y-N~deb13` |
| 19 | `kosmos-mods` | kosmos-*, meta | `X.Y-N~deb13` |
| 20 | `kosmos-welcome` | kosmos-* | `X.Y-N~deb13` |
| 21 | `kosmos-autologin` | kosmos-* | `X.Y-N~deb13` |
| 22 | `kosmos-samba-mods` | kosmos-* | `X.Y-N~deb13` |
| 23 | `kosmos-astrophotography` | kosmos-*, meta | `X.Y-N~deb13` |
| – | `kosmos-headless` | **eliminato** (sostituito da `video=` in `cmdline.txt`) | – |

Ogni pacchetto nuovo va aggiunto qui, in `scripts/packages.tsv` (se ha un upstream) e nel TODO.

### 2.4. Versioning

| Tipo | Formato | Esempio | Controllo CI | Tag git |
| --- | --- | --- | --- | --- |
| upstream | `[epoch:]X+kosmos-N~deb13` | `0.2.14+kosmos-1~deb13` | `\+kosmos-[0-9]+~deb13$` | `upstream/X` |
| `kosmos-*` | `X.Y-N~deb13` | `1.4-1~deb13` | `-[0-9]+~deb13$` | `1.4-1_deb13` |

- `+kosmos` sta nella **parte upstream**: per `dpkg` la revisione conta solo a upstream uguale, quindi `0.2.14-1kosmos1` perderebbe contro `0.2.14-2` della distro, mentre `0.2.14+kosmos-1` batte qualunque `0.2.14-N`. Va su **ogni** versione upstream, senza eccezioni.
- `N` è la revisione di packaging: una correzione di solo packaging diventa `-2` e sostituisce `-1`; un nuovo upstream riparte da `-1`.
- `~deb13` e non `~trixie`: `forky` ordina prima di `trixie`, i numeri crescono nel verso giusto. Al passaggio alla Debian successiva si aggiunge una voce di changelog per ogni pacchetto.
- **Epoch**: solo dove la distro ne ha uno. Su trixie lo ha solo **KStars, valore `5`**, e resta `5` (le nostre versioni upstream sono molto superiori a quelle della distro, non serve alzarlo). Una volta pubblicato un epoch non si toglie.
- **Niente pinning apt** (scelta dell'utente): vince la versione. Se Debian rilascia un upstream più alto, vince la distro: accettato.
- `kosmos-*`: software proprio, formato `3.0 (quilt)` (mai `3.0 (native)`, perché la revisione permette correzioni di solo packaging senza passare per `old`), niente `+kosmos`, niente epoch. `X.Y` è scelto dall'utente; `N` riparte da 1 quando cambia `X.Y`.
- Git non ammette `~` nei nomi dei riferimenti: diventa `_` (come in `gbp`), anche nell'input `ref` dei workflow.
- Verifica: `dpkg --compare-versions <a> gt <b> && echo ok`.

### 2.5. Repository dei pacchetti

- Rami `upstream/latest` (sorgente puro dell'autore) e `debian/latest` (upstream + `debian/`, ramo di default). Tag `upstream/X.Y.Z`. Il remote dell'autore si chiama `author`.
- Niente ramo `ds-clean`. Le librerie incluse nei sorgenti si lasciano e si evita di compilarle (es. `-DUSE_BUNDLED_LIBS=Off`); dopo ogni build si controlla che i binari dipendano solo da librerie di sistema (`readelf -d … | grep NEEDED`, `Depends`), perché un'opzione rinominata non dà errori.
- Aggiornamento upstream: fast-forward di `upstream/latest`, tag, **merge (mai rebase)** in `debian/latest`, poi changelog. Lo fa `scripts/pkg-update-upstream.sh`.
- **Eccezione KStars**: l'autore non tagga, ogni versione è un branch `stable-X.Y.Z` con cherry-pick, quindi la storia non è lineare. L'albero di `upstream/latest` è sempre identico alla punta di `author/stable-X.Y.Z` (`merge --no-commit -s ours` + `read-tree -u --reset`); in `debian/latest` lo stesso, poi `git checkout HEAD -- debian`. Mai conflitti a mano. I due `git diff --stat` finali devono essere vuoti (il secondo escludendo `debian/`). Script: `scripts/kstars_update.sh <X.Y.Z>`.
- Non si pubblicano pacchetti sorgente.
- `debian/gbp.conf`: `upstream-branch=upstream/latest`, `upstream-tag=upstream/%(version)s`, `debian-branch=debian/latest`, `pristine-tar=False`.
- I repository si chiamano `dpkg-<nome del pacchetto sorgente>`.
- Un pacchetto senza codice compilato è `Architecture: all`, con `debian/rules` ridotto a `dh $@` e file installati con `debian/install`; il repo (solo `arm64`) li accetta e li elenca.
- Le regole proprie di un singolo pacchetto stanno in `debian/README` nel suo repo, non qui.

### 2.6. Caso indi-3rdparty

`dpkg-indi-3rdparty` ha script di build che scaricano un tag di `indilib/indi-3rdparty` (sorgenti, librerie, SDK binari dei produttori). Si costruisce con `debian/ci/build.sh` (§2.8). Le licenze di ridistribuzione degli SDK vanno verificate prima di aprire ad altri.

### 2.7. Repository APT

- Una base `reprepro` per distro (`/bookworm/`, `/trixie/`), così i pool non si mescolano.
- Tre codename per base: `<distro>` (suite `kosmos`), `<distro>-old` (`kosmos-old`), `<distro>-testing` (`kosmos-testing`). Componente `main`, solo `arm64`.
- `current` e `old` sono **firmati**; `testing` no (nessun `SignWith`; uso personale con `trusted`, mai citato nella documentazione per gli utenti, resta sull'hosting).
- `reprepro` lavora solo in locale o nel runner; l'hosting (solo SFTP, niente SSH) si sincronizza con `lftp`.
- `reprepro export` senza argomenti chiede le chiavi di tutti i codename firmati: si usa **sempre** `export <codename>`.
- `conf/` e `db/` stanno nella cartella pubblica ma non devono essere leggibili via HTTP.
- `lftp mirror -R --delete` solo con la base completa, mai su una copia parziale. Pool: senza `--delete`, con `--only-missing`. `--parallel=1`.
- Due job non lavorano mai insieme sullo stesso `db/`, altrimenti si perdono aggiornamenti.
- Credenziali `SFTP_HOST`, `SFTP_USER`, `SFTP_PASSWORD` nei secrets del repo `build`; l'account SFTP è confinato alla cartella dei repo.
- **Host key fissata** nel secret `SFTP_KNOWN_HOSTS` (righe `known_hosts` in chiaro, una per tipo di chiave, nome host identico a `SFTP_HOST`), niente `ssh-keyscan`: sulla stessa connessione passa la password. Se l'hosting cambia chiave i workflow falliscono finché il secret non è aggiornato: voluto.
- Nei job con `container:` il `known_hosts` si scrive **sempre in `/root/.ssh/`**, mai con `~` (GitHub imposta `HOME=/github/home`, ma `ssh` legge la home dal database utenti). Nei job senza container `~/.ssh` va bene.
- Durante il porting le basi `trixie` (prova) e `trixie-empty` (vera, vuota) sono scambiate di nome sull'hosting, per provare la catena senza cambiare i riferimenti; l'URL `https://deb.kosmos-pi.org/trixie/` serve la base di prova e nessun altro utente deve usarlo. Il passaggio finale è nel TODO.

### 2.8. CI

- Tutti i workflow che scrivono sul repo APT stanno in `KosmOS-Pi/build`, con `concurrency: group: kosmos-repo`, `cancel-in-progress: false` (i gruppi valgono solo dentro un repo). Il gruppo tiene in attesa una sola run: lanciando più pacchetti insieme alcune intermedie possono essere cancellate.
- Il job di **build non riceve mai segreti**; il job di pubblicazione sì (SFTP) e riceve solo gli artifact del build.
- Build con `dpkg-buildpackage -us -uc -b`, senza `gbp` né `fetch-depth: 0`. Il changelog ha distribuzione `trixie` (o `UNRELEASED`).
- Contratto per pacchetti particolari: se esiste `debian/ci/build.sh`, il workflow lo esegue con `bash` al posto di `mk-build-deps` + `dpkg-buildpackage`; gira come root in `debian:trixie`, riceve `OUT_DIR` (dove lasciare i `.deb`) e `SRC_DIR`; il job fallisce se `OUT_DIR` non contiene `.deb`.
- Il job di build aggiunge alle sources APT la base `trixie` (firmata, verificata con il keyring) e `trixie-testing` (`Trusted: yes`) per le dipendenze interne; il keyring usato è `kosmos-bootstrap.pgp` di `pi-gen` (ramo `kosmos-trixie`), controllato contro `kosmos-archive-keyring.fpr`. **Quindi il ramo `kosmos-trixie` di pi-gen è una dipendenza della CI** e va aggiornato a ogni cambio di chiave pubblica.
- Prima della pubblicazione ogni `.deb` è controllato sulla versione (§2.4); nessun pacchetto è esentato. I `-dbgsym` non si pubblicano (opzione `include_dbgsym`).
- Pubblicazione in `testing`, in quest'ordine: download via `lftp` di `conf/`, `db/`, `dists/<codename>` (non il pool); backup del `db/` come artifact (14 giorni); `includedeb` con `--export=never` saltando le versioni già presenti; `export <codename>`; upload in ordine **pool, db, dists**.
- **Promozione** (`promote.yml`, input: nomi dei sorgenti e `repo_dir`), due job:
  - `plan`: senza chiave, scarica la base, applica la promozione in locale e passa lo stato come artifact; può servire da dry run.
  - `promote`: unico con la sottochiave (Environment `apt-signing`, approvazione richiesta); controlla il keyring contro il `.fpr`, importa la sottochiave, `export` esplicito di `trixie` e `trixie-old`, verifica con `gpgv`, upload (db, old, current), verifica di quanto pubblicato.
  - Regole per sorgente: mai downgrade; una sola versione upstream in `testing`; prima release → copia in `current`; **nuova upstream** → `current` passa in `old` (sostituendo `old` di quel sorgente) e `testing` va in `current`; **stessa upstream** (revisione di packaging) → `current` sostituito, `old` intatto.
- Action: si tiene la major corrente quando GitHub segnala una deprecazione; dopo ogni aggiornamento si prova un run completo con un pacchetto nuovo.
- `build/scripts/` contiene script di gestione locale, senza credenziali, per la sola macchina personale.
- Il build dell'immagine (`build-image`, solo `workflow_dispatch`, senza secret, `ubuntu-24.04-arm`) installa le dipendenze leggendo `pi-gen/depends` e, con `release` attivo, pubblica una pre-release di prova nel repo `build` (non come artifact, per la quota di storage). Le Release di prova si cancellano dal portale **insieme al tag** `image-test-N`.

### 2.9. Politica dei rilasci

- `old` contiene la **precedente versione upstream**, non ogni push. Una revisione `-2` della stessa upstream sostituisce la `-1` dovunque e non genera promozione in `old`.
- Cadenza circa bimestrale.
- Prima di aprire ad altri servono: `kosmos-archive-keyring` e `kosmos-apt-config` pubblicati, fingerprint della primaria su più canali (§2.10), licenze degli SDK verificate, rollback documentato.

### 2.10. Chiavi di firma

Dettaglio operativo (comandi, file, rotazione, revoca) in «Chiavi di firma e keyring APT». Qui le decisioni.

- Per trixie la chiave è **nuova**. La chiave bookworm resta com'è e continua a firmare quel repo: `keys/kosmos.gpg.asc` non si sostituisce.
- Primaria ed25519 **solo `[C]`**, senza scadenza, con passphrase, **offline**, mai in CI. Backup cifrato in due copie e certificato di revoca creati subito.
- Due sottochiavi `[S]` ed25519 senza scadenza: una **attiva** (copia in CI) e una **di riserva** solo offline, inclusa nel keyring pubblicato fin dall'inizio, per sostituire una sottochiave compromessa senza che gli utenti installino a mano un keyring nuovo.
- Nessuna scadenza su nessuna chiave (per non dover ricordare i rinnovi); compensazioni: revoca preventiva, backup, riserva, procedure.
- La copia CI non ha passphrase (si ottiene con keyring temporaneo in `/dev/shm`, `--export-secret-subkeys`).
- `SignWith` contiene il fingerprint della sottochiave attiva, **senza `!`**. Firmano solo `trixie` e `trixie-old`.
- Secret `APT_SIGNING_KEY` nell'Environment `apt-signing` di `build`: solo ramo `main`, approvazione richiesta, «Allow administrators to bypass» **disattivato**; nessun secret omonimo a livello di repository; lo legge solo `promote`.
- Keyring utenti: `kosmos-archive-keyring.pgp` binario in `/usr/share/keyrings/`; `Signed-By` punta al file, mai a un fingerprint. Un solo blocco `.sources` con `Suites: trixie trixie-old`.
- Cambi di sottochiave, revoche e scadenze si distribuiscono cambiando il **contenuto** del keyring (nuovo `X.Y`), non il `.sources` né il fingerprint della primaria.
- Rotazione: **prima** il keyring nuovo agli utenti, **poi** `SignWith` e secret, la vecchia si revoca per ultima. Firmare con una sottochiave che gli utenti non hanno fa fallire il loro `apt update`.
- Fiducia ancorata al fingerprint **completo (40 caratteri) della primaria**, pubblicato su più canali indipendenti (sito, README di `build`, `pi-gen`); mai l'ID corto. Chi controlla l'hosting serve sia i `.deb` sia la chiave: un canale solo non basta.
- Il fingerprint della sottochiave non è un segreto: sta in `conf/distributions`. Il rischio di `conf/distributions` pubblico è l'integrità, non la riservatezza.

### 2.11. Immagine e primo avvio

- pi-gen fino a **stage2** (`STAGE_LIST="stage0 stage1 stage2"`): Lite di circa 500 MB. Il resto si installa al primo avvio con `kosmos-setup.sh` (`kosmos-desktop`, `kosmos-mods`, `kosmos-astrophotography`).
- **Localizzazione, utente, WiFi**: l'immagine non conosce l'utente di destinazione, quindi `config` lascia i default di pi-gen (locale, fuso, tastiera) e non impone né country code né username. La documentazione prescrive di **usare rpi-imager** per preimpostare nome utente, WiFi e country, localizzazione e tastiera. Chi masterizza con un altro metodo deve fare il primo avvio con monitor, mouse e tastiera: parte l'onboarding di Raspberry Pi OS e chiede i dati essenziali.
- L'utente `kosmonaut` (`FIRST_USER_NAME`) viene rinominato dall'onboarding, molto prima di `kosmos-setup`: quando si installa `kosmos-autologin` il nome è già definitivo. L'autologin SDDM sostituisce lo username reale in un file in `/etc/sddm.conf.d/`.
- Senza `WPA_COUNTRY` il WiFi resta spento (NetworkManager `WirelessEnabled=false`) e `SelfHotspot` non parte: è il comportamento voluto in attesa del country code.
- Il **repo KosmOS lo configura l'immagine**, non `kosmos-setup.sh`: in stage2 (`99-kosmos-setup/00-run.sh`, in chroot) un `kosmos-bootstrap.sources` provvisorio con `Signed-By` verso `kosmos-bootstrap.pgp` permette di installare `kosmos-archive-keyring` e `kosmos-apt-config` verificando la firma; poi i due file provvisori si cancellano (altrimenti doppio `Signed-By`). Gli script di pi-gen partono con `-e`, così un errore ferma il build. `kosmos-setup.sh` si limita a installare i pacchetti.
- Il file `kosmos-archive-keyring.fpr` (fingerprint della primaria, una riga, 40 caratteri) è confrontato col keyring di bootstrap sia nei workflow sia nello script di pi-gen. Protegge dagli errori, non da un attacco (stesso repo); la protezione vera è il confronto con i canali di §2.10.
- Il keyring di bootstrap va aggiornato a ogni modifica della chiave pubblica; esiste in tre copie (pacchetto, `pi-gen`, `keys/` sul server) che devono restare identiche.
- Primo avvio: `kosmos-setup.service` (dopo `network-online.target`) lancia il wrapper, che usa file-flag in `/var/lib/kosmos-setup/` (`in-progress`, `no-network`, `failed`, `done`), attende la sincronizzazione NTP (max 60 s: senza RTC le firme risulterebbero «Not live yet»), e si riavvia da solo quando NetworkManager rileva la rete (dispatcher). `check-kosmos-setup` e il messaggio al login mostrano lo stato. A fine setup si abilita `vncserver-x11-serviced` e `graphical.target` come default.
- `cloud-init` è installato ma `ENABLE_CLOUD_INIT` non è impostato; il catalogo usa `init_format: systemd`.
- Catalogo rpi-imager: **prodotto da `build-image`** a ogni build e pubblicato nella stessa Release dell'immagine con `SHA256SUMS`. Il template `imager/kosmos-template.json` contiene i soli campi statici; i dinamici (`url`, `release_date`, `extract_size`, `extract_sha256`, `image_download_size`, `image_download_sha256`) li scrive `jq` (numeri con `--argjson`) e un `jq -e` fa fallire il passo se qualcosa è vuoto o zero. Lo step di checksum è diviso in «Uncompressed Checksums» (prima della compressione, `DEPLOY_COMPRESSION=none`) e «Compression and Checksums» (`xz`, rinomina `image_<nome>.xz`). Il tag `image-test-<run_number>` è definito una volta (`TAG`). Le Release sono di prova; per gli utenti servirà un URL fisso del catalogo, copiato al rilascio vero.

### 2.12. Sessione grafica e default del desktop

- **X11, non Wayland** (compatibilità con KStars e VNC): `Session=plasmax11` (`plasma.desktop` è Wayland); `kosmos-desktop-defaults` dipende da `kwin-x11`.
- I default valgono **solo per l'immagine KosmOS**: stanno in `kosmos-desktop-defaults` (`/etc/xdg/`, incluso in `kosmos-desktop`), non in pacchetti utili anche da soli. Il pacchetto dipende dai programmi che configura. Contiene solo impostazioni, nessun asset grafico.
- Ordine dei metodi: (1) chiavi KConfig semplici in `/etc/xdg/`; (2) layout di Plasma nel look-and-feel di `kosmos-plasma-theme`; (3) `/etc/skel` solo per file che devono esistere nella home (si copia solo alla creazione dell'utente).
- **Mai distribuire configurazioni generate da una sessione reale** (UUID, `$Version`, cache, geometrie, nomi file dell'utente).
- Layout del pannello: `contents/layouts/org.kde.plasma.desktop-layout.js` dei look-and-feel (light e dark identici) carica il pannello di serie e modifica l'icona del lanciatore e `launchers` di `icontasks`. Le liste si passano come **array** (con una stringa compaiono dal secondo login). Voci: `preferred://browser`, `applications:<nome>.desktop`. Desktop senza icone.
- Schermo mai spento (`powerdevilrc`, profilo AC). Orca non è installato.
- **Avatar**: un solo file reale `/usr/share/kosmos/face.icon` (PNG 256×256) in `kosmos-plasma-theme`; symlink in `/usr/share/sddm/themes/KosmOS/faces/.face.icon` (`debian/links`, il file non deve esistere anche nel repo) e in `/etc/skel/.face` e `.face.icon` (stage0 di pi-gen). Il greeter SDDM gira come `sddm` e non attraversa le home: per chi non ha scelto un avatar usa il fallback della **cartella del tema**; l'avatar scelto passa da AccountsService e ha la precedenza. `FacesDir` non serve.
- `kosmos-notifications`: nessun KCM (Qt5 non caricabile su Plasma 6); gestione da Impostazioni → Notifiche tramite un `.desktop` in `/usr/share/applications` senza `NoDisplay` e hint `desktop-entry` nello script; l'autostart è un `.desktop` separato in `/etc/xdg/autostart`; timeout su `notify-send`, link nel corpo, al massimo `MAX_DISPLAYS` visualizzazioni per notizia.
- `kosmos-archive-keyring` e `kosmos-apt-config`: vedi «Chiavi di firma e keyring APT», §4 (`kosmos.sources` è un conffile: le modifiche dell'utente sopravvivono).
- Rispettando quanto al §2.1, le personalizzazioni del desktop devono andare nelle cartelle del proprio tema.
