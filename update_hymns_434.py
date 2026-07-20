import json

new_hymns_data = [
    {
        "id": 433,
        "title": "DIOS ME GUARDA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Han pasado los meses y los años
Pero Dios todavía me ha guardado
Han venido vientos y tempestades
Pero Dios todavía me ha guardado.

CORO: ¡Gloria al Señor, hoy puedo decir
Hasta aquí me ayudo Jehová
Gloria al Señor, hoy puedo decir
Hasta aquí me ayudo Jehová.

2. Muchas veces vino a mí el desaliento
De dejar los caminos de Dios
Y hasta el polvo de la tierra me humillaba
Pero Dios siempre me levantaba."""
    },
    {
        "id": 434,
        "title": "SÍ VOLVERÁ",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Cuando miro los cielos,
Las márgenes del Río
La tierra en gravedad,
Medito y me extasío
Pensando que mi Cristo
Muy pronto volverá
El hombre está afligido,
Los pueblos confundidos
Y claman por la paz,
Y en medio de este hastío
Los fieles y escogidos pregonan: Volverá.

CORO: Sí volverá, yo se muy bien
Que volverá
Promesa fiel faltar jamás
Lo dijo en el oriente,
Nació la tea ardiente
Del príncipe de paz,
Los tiempos han pasado
El hombre lo ha olvidado,
Más sé que volverá.

2. Los sabios y entendidos,
Cual ave sin su nido
Emigran por la paz,
Confunden las naciones
Buscando soluciones
Y hablando el verbo paz.
Y cuando ha emigrado,
La efímera esperanza
De la frustrada paz,
Tormento en las naciones
Tronaron los cañones,
Mi Cristo viene ya.

3. Desde la misma cuna
Nacimos escuchando
El canto volverá,
El niño se hizo hombre
El hombre ya es anciano,
Y el mismo canto está
Hoy siendo un mensajero
Desde áridos senderos
Predico ésta verdad,
Con gozo y con ayes
Y aunque mi voz se apague,
Yo sé que volverá."""
    },
    {
        "id": 435,
        "title": "EL PRIMER AMOR",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. ¿Dónde está el amor
Que un día yo te di
El amor tan grande
Que sentías tú por mí
Dónde está el amor,
Aquel amor primero
Qué solo anhelabas
Para tu Dios vivir?

CORO: Acaso te olvidaste
De donde te saqué
Y el precio tan inmenso,
Que en la cruz por ti pagué
Acaso te olvidaste
Que estabas tú perdido
Y que del mismo infierno
Tú alma yo libré.

2. ¿Dónde está el amor
Que te hizo correr?
Sin importarte nada
Querías tu ser fiel
¿Dónde está el amor,
Yo te pregunto ahora?
Dejaste que los años
Lo hicieran perecer.

3. Acuérdate por tanto
De donde has caído
Y vuelve arrepentido
A las plantas del Señor.
Y sirve como antes
En tus primeras obras
Enciende pues la llama
De tu primer amor."""
    },
    {
        "id": 436,
        "title": "A DIOS SEA LA GLORIA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Como podré agradecer tanto amor
Que me has dado a mí
Cosas tan maravillosas
Que no logro yo comprender
Las voces de millones de ángeles
No podrían expresar mi gratitud
Todo lo que soy y lo que yo espero ser
Se lo debo todo a Él.

CORO: A Dios sea la gloria
A Dios sea la gloria
A Dios sea la gloria
Por lo que Él ha hecho en mi
Con su sangre me ha lavado
Su poder me ha transformado
A Dios le doy la gloria
Por lo que Él ha hecho en mi.

2. Quisiera consagrar mi vida a Él
Y ser agradecido con mi Señor
Y si algo de gloria recibo en mi
Que toda sea la gloria a Dios.
Porque suyo es el Reino
El Poder y la Gloria
Por siempre, por siempre,
Amén, amén, amén."""
    },
    {
        "id": 437,
        "title": "TENGO GANAS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Tengo ganas de cruzar el cielo azul
Como paloma poder volar y volar
Y mirar las estrellas y tocarlas
Y ver el día y la noche y el sol
Y cruzar por las galaxias, ver planetas
Y encontrar esa puerta
Que me dejará entrar...

CORO: Donde Tú estás, en tu Trono
A la diestra de mi Padre Celestial
Allá quiero ir y por siempre
Yo quedarme allá.

2. Tengo ganas de caminar por esas calles
Calles de oro, lugar hermoso celestial
Y tocar mi instrumento de oro
Notas preciosas, melodía celestial
Y sentir que por fin estoy contigo
Que en tu gloria yo estoy
Y nunca me alejaré de...

3. Y nunca más volver a la tierra
Donde sólo hay tinieblas y maldad
Y nunca más llorar, y nunca más pecar
Contigo quiero estar en tu trono celestial."""
    },
    {
        "id": 438,
        "title": "ANOCHE TUVE UN SUEÑO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Anoche tuve un sueño
Sublime arrobador
Soñaba yo en Jerusalén
Y al cielo en su esplendor
Oí cantar a ángeles un coro celestial
En tanto se escuchaba
Un gran célico cantar.

CORO: Jerusalén, Jerusalén
Prorrumpe en voz triunfal
Hosanna en las alturas
Hosanna, al Señor tu Rey.

2. Más luego el sueño se pasó
Y la quietud reinó
Cesaron las hosannas y el célico cantar
El sol su rostro encubrió y la quietud reinó
Y la sombra de una cruz
En el calvario apareció."""
    },
    {
        "id": 439,
        "title": "CON QUE PAGARÉ",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Con que pagaremos este inmenso amor,
Que diste tu vida por el vil pecador.
Señor Jesucristo, conforta mi alma,
Para que yo pueda vencer esta lucha
Y servirte mejor.

CORO: No tengo que darte
Por amarme tanto,
Recibe este canto
Mezclado con llanto
De mi corazón.

2. Y cuando la noche extienda su manto,
Mis ojos en llanto fijaré yo a ti,
Alzando mis ojos veré las estrellas,
Ya sé que tras ellas cual padre amoroso
Tú velas por mi.

3. No puedo pagarte con oro ni plata,
El gran sacrificio que hiciste por mi,
En cambio recibe mi ofrenda humillada,
La ofrenda humillada, Señor Jesucristo,
De mi corazón."""
    },
    {
        "id": 440,
        "title": "NO TEMAS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. No temas, confía, victoria te dará el Señor,
Él es tu protector, Jehová tu sanador,
Tu Dios de amor, tu salvación.

2. No temas, el Señor está contigo
Él es tu mejor amigo, Él jamás te dejará
No temas, aunque fuerte sople el viento
Y te turben pensamientos,
El Señor te sostendrá,
No temas, si el infierno se levanta
Es Jehová el que te guarda,
Él jamás se dormirá.

CORO: No temas, confía,
Victoria te dará el Señor
Él es tu protector, Jehová tu sanador
Tu Dios de amor, tu salvación.

3. No temas, Jehová es tu castillo
Fortaleza de tu vida, es tu luz y salvación
No temas, si la cruel desesperanza
Con su sombra te abraza,
El Señor te sostendrá,
No temas, si luchada está tu alma
Es Jehová El que te guarda,
Él jamás se dormirá."""
    },
    {
        "id": 441,
        "title": "ALMA MÍA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Alma mía, alma mía bendice a Jehová
Y no te olvides jamás, jamás
De todo el bien, su amor, su gran bondad
Que cada día te da fuerzas, te da paz
Que va contigo donde quiera que tu vas.

CORO: No, no te olvides
Que el Señor te perdonó te dijo viva,
Que estando lejos de tu Dios
Eras muy triste
Y ahora ríes y ahora ríes:
No, no te olvides
Que dio su sangre
Por salvar tu pobre alma
Que fue herida sin piedad
Porque te amaba,
Oh alma mía y aún te ama
No, no te olvides: no, no te olvides
Alma mía.

2. Alma mía, alma mía bendice a Jehová
Y no te canses jamás de alabar
Su santo nombre en Espíritu y verdad
Él te corona y te sacia de bondad
Rejuvenece como el águila al volar."""
    },
    {
        "id": 442,
        "title": "LA QUINTA FILA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. A veces yo iba al templo y no sentía a Dios
Y en aquella noche algo aconteció
Un hermano muy alegre me recibió
Y me senté bien atrás.
Cinco bancos atrás yo quedé
Escuche la historia de mi Jesús
Da salvación y de condenación
Yo escuché desde atrás.

2. El mensaje del hermano
En aquel momento ya
Habló con poder a mi pobre corazón
Dice él que Jesús por mí sufrió allí
Muerte de cruz por mí sufrió
El coro cantando me conmovió
Perdido me ví, busque a Jesús
Entonces yo sentí el perdón de Jesús
Di cinco bancos atrás.

3. Sentí mucha alegría en mi corazón al fin
La presencia de Jesús me transformó
A través de los años yo jamás me olvidaré
Aquella noche en que a Cristo encontré
El coro cantando me conmovió
Perdido me ví, busque a Jesús
Entonces yo sentí el perdón de Jesús
De cinco bancos atrás
Yo ví a Jesús desde atrás."""
    },
    {
        "id": 443,
        "title": "CON MIL ANGUSTIAS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Con mil angustias y lleno de quebrantos
Marcha el cristiano cuando
A Dios quiere agradar
Más no importa aunque en medio
De las pruebas
La salud de mi Jesús no faltará.

CORO: Sólo no voy en medio de las pruebas,
Decía Pablo aquel testigo fiel,
Porque aunque voy atado
Con cadenas
Llevo en mi pecho la esperanza
De Israel.

2. Libre de dudas y libre de quebrantos
Marcha el cristiano porque Cristo va con él
En su esperanza
Se vislumbra en mil albores
Pues su esperanza está en
Un nuevo amanecer."""
    },
    {
        "id": 444,
        "title": "A SOLAS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. A solas al huerto yo voy
Cuando duerme aún la Floresta
Y en quietud y paz con Jesús estoy
Oyendo atento allí su voz.

CORO: Él conmigo está, puedo oír su voz
Y que suyo dice seré
Y el encanto que hallo con Él allí
Con nadie tener podré.

2. Con Él encantado yo estoy
Aunque en torno lleguen las sombras
Más me ordena ir a escuchar su voz,
Su voz doquier la pena esté.

3. Tan dulce es la voz del Señor
Que las aves guardan silencio
[...falta el resto de la letra en la foto...]"""
    }
]

file_path = "assets/json/hymns.json"
with open(file_path, "r", encoding="utf-8") as f:
    hymns = json.load(f)

for new_hymn in new_hymns_data:
    idx_to_replace = -1
    for i, h in enumerate(hymns):
        if h["id"] == new_hymn["id"]:
            idx_to_replace = i
            break
    
    if idx_to_replace != -1:
        hymns[idx_to_replace] = new_hymn
    else:
        hymns.append(new_hymn)

# Sort hymns by ID to keep it tidy
hymns.sort(key=lambda x: x["id"])

with open(file_path, "w", encoding="utf-8") as f:
    json.dump(hymns, f, ensure_ascii=False, indent=2)

print("Hymns updated successfully.")
