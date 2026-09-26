# printino-mac-menu-bar

Hai comprato la stampante termica dell'Action Fichero e non vuoi scaricare l'app ufficiale per ovvi motivi? Ecco un'applicazione nativa per macOS scritta in Swift e SwiftUI per controllare e stampare etichette direttamente dalla barra del Mac.

Permette di stampare testo, emoji, immagini personalizzate, codici QR e codici a barre completamente offline dalla barra dei menu, con drag-and-drop.

---

## Perché non usare l'app ufficiale?

L'applicazione ufficiale per Android (`com.lj.fichero`) richiede ben **26 permessi di sistema**. Alcuni sono spiegabili dal funzionamento dell'hardware o da vincoli di sistema:
- `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`: richiesti da Android per effettuare scansioni Bluetooth LE.
- `CAMERA`: usata per acquisire foto o scansionare codici a barre da riprodurre.
- `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`: residui ereditati dal codice sorgente condiviso, che gestisce oltre 159 modelli diversi (inclusi dispositivi con connettività Wi-Fi assente su questo modello).

Tuttavia, l'app include permessi che non hanno alcun legame funzionale con la stampa di un'etichetta:
- `AD_ID` e `ACCESS_ADSERVICES_AD_ID`: identificativo pubblicitario persistente per il tracciamento del profilo utente tra le app.
- `ACCESS_ADSERVICES_ATTRIBUTION`: analisi di conversione e attribuzione delle campagne pubblicitarie.
- `BIND_GET_INSTALL_REFERRER`: monitoraggio della sorgente di installazione dal marketplace.

Il pacchetto dell'app è in realtà una soluzione white-label sviluppata da terze parti (**LuckPrinter SDK**, `com.luckprinter.sdk_new`), personalizzata con il marchio Fichero. **printino** elimina completamente questi intermediari, interfacciandosi direttamente con il chip Bluetooth della stampante a livello locale senza raccogliere né trasmettere dati.

---

## Funzionalità

- **Nativa per macOS Menu Bar:** Risiede esclusivamente nella barra dei menu senza occupare spazio nel Dock.
- **Driver CoreBluetooth Diretto:** Comunica con l'hardware tramite il protocollo inverso AiYin, senza dipendenze esterne o app per smartphone.
- **Canvas Interattivo con Drag-and-Drop:** Possibilità di trascinare e riposizionare l'anteprima per regolare la posizione degli elementi prima dell'invio alla testina termica.
- **Elementi di Stampa Compositi:**
  - Testo multi-riga dinamico con regolazione puntuale dei punti (pt).
  - Scorciatoie rapide per l'inserimento di emoji.
  - Importazione di immagini personalizzate con ridimensionamento automatico per la testina di stampa.
  - Generazione nativa di codici QR tramite `CIQRCodeGenerator`.
  - Generazione nativa di codici a barre Code-128 tramite `CICode128BarcodeGenerator`.
- **Integrazione Hardware:**
  -    Lettura percentuale della batteria e monitoraggio stato.
  - Tre livelli di densità termica hardware (Leggera, Media, Forte).
  - Allineamento automatico e avanzamento carta (form feed).

---

## Specifiche Hardware e Dettagli del Protocollo

Il dispositivo venduto come **Action Fichero D11s** è basato su hardware **AiYin / LuckPrinter** (produttore: *Xiamen Print Future Technology Co., Ltd*, firmware verificato 2.4.6).

### Hardware

- **Larghezza Testina:** 96 pixel (12 byte per riga)
- **Risoluzione:** 203 DPI (8 punti/mm)
- **Batteria:** 18500 Li-Ion, 1200 mAh
- **Ricarica:** USB-C, 5V 1A
- **Connessione:** Classic Bluetooth SPP (`00001101-0000-1000-8000-00805F9B34FB`) + BLE
- **Prefissi Nomi Bluetooth:** `FICHERO_XXXX`, `D11s_`

### Servizi BLE UART

Ciascuno dei seguenti 4 servizi è equivalente sul firmware della stampante:

| Servizio UUID | Scrittura (Write) | Notifica (Notify) |
|---|---|---|
| `000018f0-0000-1000-8000-00805f9b34fb` | `2af1` | `2af0` |
| `0000ff00-0000-1000-8000-00805f9b34fb` | `ff02` | `ff01` (+ `ff03`) |
| `e7810a71-73ae-499d-8c15-faa9aef0c3f2` | `bef8d6c9...` | `bef8d6c9...` (Write + Notify) |
| `49535343-fe7d-4ae5-8fa9-9fafd205e455` | `4953...9bb3` | `4953...9616` (+ `aca3`) |

### Comandi Informativi (Verificati su Hardware)

| Byte | Comando | Risposta | Esempio |
|---|---|---|---|
| `10 FF 20 F0` | Modello | Stringa ASCII | `"D11s"` |
| `10 FF 20 F1` | Versione Firmware | Stringa ASCII | `"2.4.6"` |
| `10 FF 20 F2` | Numero di Serie | Stringa ASCII | |
| `10 FF 20 EF` | Versione Boot | Stringa ASCII | `"V1.00"` |
| `10 FF 50 F1` | Livello Batteria | 2 byte: `[stato, percentuale]` | `00 56` = 86% |
| `10 FF 40` | Stato Operativo | 1 byte bitmask (vedi sotto) | `00` = pronto |
| `10 FF 11` | Lettura Densità | 3 byte | `01 14 01` |
| `10 FF 13` | Timeout Spegnimento | 2 byte big-endian (minuti) | `00 14` = 20 min |
| `10 FF 70` | Tutte le Info | Stringa ASCII delimitata da pipe `\|` | vedi sotto |

#### Decodifica Bitmask Stato (`10 FF 40`)

| Bit | Maschera | Significato |
|---|---|---|
| 0 | `0x01` | In fase di stampa |
| 1 | `0x02` | Coperchio aperto |
| 2 | `0x04` | Carta esaurita |
| 3 | `0x08` | Batteria scarica |
| 4 | `0x10` | Surriscaldamento (alternativo) |
| 5 | `0x20` | In carica |
| 6 | `0x40` | Surriscaldamento |

`0x00` = Nessun errore, pronta per la stampa.

#### (`10 FF 70`)

Formato: `NOME_BT|MAC_CLASSIC|MAC_BLE|FIRMWARE|SERIALE|BATTERIA`  
Esempio: `FICHERO_XXXX|XX:XX:XX:XX:XX:XX|XX:XX:XX:XX:XX:XX|2.4.6|SERIAL|86`

### Comandi di Configurazione

| Byte | Comando | Parametri | Risposta |
|---|---|---|---|
| `10 FF 10 00 nn` | Imposta densità | `0`=leggera, `1`=media, `2`=forte | `"OK"` |
| `10 FF 84 nn` | Imposta carta | `0`=gap/etichetta, `1`=black mark, `2`=continua | `"OK"` |
| `10 FF 12 HH LL` | Spegnimento automatico | Minuti in big-endian | `"OK"` |
| `10 FF 04` | Reset di fabbrica | Nessuno | `"OK"` |
| `10 FF C0 nn` | Imposta velocità | Valore numerico velocità | 4 byte |

### Comandi Non Supportati su D11s

I seguenti comandi dell'SDK generale LuckPrinter non producono risposta su D11s:
- `10 FF 20 A0` (Lettura velocità)
- `10 FF B0` (Formato orario)
- `10 FF 15 LL HH` (Imposta larghezza testina: fissa a 96 px)
- `1F 70 01 nn` (Riscaldamento manuale)
- `1F 11 11 nn` (Riavvolgimento carta)

### Sequenza di Stampa (AiYin D11s)

1. `10 FF 10 00 nn` -> Imposta densità (`0`, `1` o `2`) -> Attesa 100 ms
2. `10 FF 84 00` -> Imposta tipo carta a gap -> Attesa 50 ms
3. `00` $\times$ 12 -> Risveglio testina termica (12 byte nulli) -> Attesa 50 ms
4. `10 FF FE 01` -> Abilita controller termico (specifico per dispositivi AiYin) -> Attesa 50 ms
5. `1D 76 30 00 0C 00 yL yH` -> Intestazione raster ESC/POS (`GS v 0`), seguita dai dati bitmap a 1-bit (MSB a sinistra)
6. Invio dati suddivisi in pacchetti da 200 byte con delay di 20 ms
7. Attesa 500 ms per la conclusione dell'azione termica
8. `1D 0C` -> Form feed (avanzamento all'etichetta successiva) -> Attesa 300 ms
9. `10 FF FE 45` -> Disabilita controller termico (attende byte `0xAA` o risposta `"OK"`)

> **Importante:** I comandi di abilitazione/arresto differiscono in base al chip:
> - **AiYin (D11s, D12):** `10 FF FE 01` / `10 FF FE 45`
> - **Lujiang (L13, ecc.):** `10 FF F1 03` / `10 FF F1 45`  
> L'invio dei comandi Lujiang su hardware AiYin causa la ricezione silenziosa dei dati senza avviare la stampa.

### Formato Immagine Raster

- **Intestazione:** `1D 76 30 mm xL xH yL yH`
  - `mm`: Modalità (`0`=normale)
  - `xL xH`: Larghezza in byte, little-endian (`0C 00` = 12 byte = 96 pixel)
  - `yL yH`: Altezza in righe, little-endian (es. etichetta da 30 mm = 240 righe = `F0 00`)
- **Dati Pixel:** Ciascun byte codifica 8 pixel in sequenza (bit più significativo = pixel a sinistra; `1` = nero/riscaldatore attivo, `0` = bianco).

---
## Crediti
Questo non sarebbe stato possibile senza l'analisi condotta in [0xMH/fichero-printer](https://github.com/0xMH/fichero-printer). Se cercate una web app per stampare direttamente dal browser la trovate nella sua repo.
---
---
## Licenza
MIT
---
---
## Struttura del Progetto

```text
printino/
├── App/
│   └── FicheroApp.swift            
├── Core/
│   ├── Bluetooth/
│   │   ├── BLEConstants.swift      
│   │   └── BLEManager.swift        
│   ├── Imaging/
│   │   ├── BitmapConverter.swift   
│   │   └── LabelRendering.swift    
│   └── Protocol/
│       ├── FicheroCommand.swift    
│       └── PacketBuilder.swift    
├── Features/
│   └── MenuBar/
│       ├── Models/
│       │   └── LabelComposition.swift 
│       ├── ViewModels/
│       │   └── MenuBarViewModel.swift 
│       └── Views/
│           └── MenuBarContentView.swift 
└── Resources/
    └── Info.plist                 
