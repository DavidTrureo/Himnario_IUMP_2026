import json
import copy

new_hymns_data = [
    {
        "id": 421,
        "title": "TENER, QUISIERA TENER",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Tener, quisiera tener,
La fe que tuvo Abraham,
Amor también poseer
Como habla el apóstol Juan.
Se sabio cual Salomón
Y como Daniel revelar,
Ser fuerte como Sansón
Y al cielo poder entrar.

CORO: Tener quisiera tener,
Lo que tenia Jesús,
Sentir una misma cosa,
Tener una misma luz.
Poder agradar al Padre,
Cumpliendo su voluntad,
Entonces que dicha
Inmensa, gozar por la eternidad.

2. También quisiera pelear,
Valiente como David,
Luchar hasta derrotar,
Y alzar la cruz en la lid.
Cual gozo es ser esforzado,
Y como Pablo sufrido,
Llevar a Cristo grabado,
Por ser su amor tan querido.

3. Tener quisiera tener,
Visiones como Isaías.
Para poder conocer
Lo que en el cielo se haría.
Vivir en Apocalipsis
Capítulo veintiuno,
Entonces que bendiciones
Será para cada uno."""
    },
    {
        "id": 422,
        "title": "DIVINO COMPAÑERO DEL CAMINO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Divino compañero del camino,
Tu presencia siento yo al caminar,
Tu has disipado toda sombra,
Hoy tengo luz, la luz bendita de tu amor.

CORO: Quédate Señor, que se hace tarde
Te ofrezco el corazón para morar.
Hazlo tu morada permanente,
Acéptalo, acéptalo hoy mi Salvador.

2. Contigo, la distancia se hace corta,
No habrá sed ni el sol fatigará,
Si en el mar las olas amenazan
Majestuoso sobre ellas andarás.

3. Las sombras de la noche se aproximan
Y en ella el tentador acechará,
No me dejes solo en el camino,
Ayúdame, ayúdame hasta llegar."""
    },
    {
        "id": 423,
        "title": "CREO EN TI",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Quise huir de Ti,
Pero tu mano fue sobre mi
Al saber que tus caminos iba a dejar
Como hombre fui a buscar
Mejor vida, mejor vida para mi.

CORO: Y he recorrido largos senderos
Al caminar
Y te puedo decir que no hay
Mejor amor, mejor amor,
Que el de Dios.
Creo en Ti, porque Tú eres
Mi esperanza para vivir
Porque me hiciste a tu imagen
Oh, Señor
Porque Tú eres mis pasos al caminar,
Mi voz, al cantar
Creo en Ti, porque Tú eres
Porque Tú eres mi voz al hablar
Porque Tú eres mi mente al pensar
Creo en Ti, creo en Ti, oh Señor
Creo en Ti.

2. Y ahora que pienso en los que quedan
En los que quedan sin salvación
Pena me da el saber
Que para ellos la salvación también fue."""
    },
    {
        "id": 424,
        "title": "PODER, MARAVILLOSO PODER",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Cuando acepte a mi Cristo
Como mi salvador
De pronto todo cambió
Mi vida de pecado
Por siempre terminó
Su espíritu Jesús me dio.

CORO: Poder maravilloso poder
Que gozo siento yo en mi ser
Del día de Pentecostés
Hoy siento el poder
Poder maravilloso poder (bis).

2. Yo anduve por el mundo
Con un vacio en mi alma
Jesús lo vino a llenar
Ahora vivo alegre
Y tengo la esperanza
De siempre con Él estar.

3. Dios dijo a Nicodemo
Que al Reino de los Cielos
Nadie podía entrar
Porque es necesario volver a nacer
Tú necesitas el poder."""
    },
    {
        "id": 425,
        "title": "YO CAMINÉ POR LOS CAMINOS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Yo caminé por los caminos de este mundo
Donde placeres deleitan al corazón,
Pero hay un sitio para mí como ninguno
Donde mi alma encontró felicidad,
Como un errante vagué por esta vida
En los placeres busqué felicidad,
Pero confieso que feliz nunca lo he sido
Porque no existe estando lejos de mi Dios.

CORO: Oh mi Señor, deja que llore
Y te adore mi Señor,
Porque mis lágrimas
No puedo contener
Cuando yo siento Tú presencia
Mi Señor.
Quisiera estar siempre a tu lado y no
Separarme más,
Porque en el mundo
No hay sitio para mi
Donde mi alma se sienta tan feliz.

2. Tú curaste y vendaste mis heridas
Cuando a la vera del camino me quedé
Muchos pasaron sobre mí sin socorrerme
Y me dejaron sólo en el dolor
Pero tú fuiste el buen Samaritano,
Que conmovido al verme en mi dolor
Y tuviste la bondad para ayudarme
Y en tus brazos me llevaste al mesón."""
    },
    {
        "id": 426,
        "title": "SALMO 121",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Alzaré mis ojos a los montes
¿De dónde vendrá mi socorro?
Mi socorro viene de Jehová
Que hizo los cielos y la tierra.

CORO: No dará tu pie al resbaladero
Ni se dormirá el que guarda a Israel
He aquí no se adormecerá
Ni se dormirá el que guarda a Israel.

2. Jehová es tu guardador
Jehová es tu sombra a tu mano derecha
El sol no te fatigará de día
Ni la luna, ni la luna de noche.

3. Jehová te guardará de todo mal
Y guardará tu alma
Jehová guardará tu salida y tu entrada
Desde ahora y para siempre, amén."""
    },
    {
        "id": 427,
        "title": "NO TE DEJARÉ",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Dios suplirá todo lo que falte
En la grandeza de su gloria
Prosperará siempre mi alma
Y me dará la victoria
Aunque rujan las huestes malignas
Él estará conmigo
Jehová la fortaleza de los siglos
Es mi mejor amigo.

CORO: No te dejaré, no te dejaré
De día ni de noche, no te dejaré
No te dejaré, no te dejaré
No te dejaré, no te dejaré.

2. Jehová es mi fuerte castillo
Mi amparo, es la roca de Horeb
Su voz como ríos de agua
Sacia por siempre mi sed.
Jehová cambia el llanto por gozo
Al triste le ofrece la paz
Al ciego da vista y al cojo levanta
Y salvación Él les da."""
    },
    {
        "id": 428,
        "title": "SI CRUZAS ESTE VALLE TENEBROSO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Si cruzas este valle tenebroso
Si luz en tu camino y fatigado
Si nadie a tu clamor ha respondido
No temas que el Señor está a tu lado.

CORO: Trae al Señor dolores y quebrantos
Y ven a Él con toda tu impureza
Y tú te harás de su bondad inmensa
Te llenará de amor sublime y santo.

2. Jesús es viva fuente de consuelo
Que quita los pesares de la vida
Que trajo cual paloma desde el cielo
El bálsamo de amor al alma herida.

3. Escucha el amoroso llamamiento
De Cristo inocentísimo cordero
Que vino a redimirnos con su sangre
Muriendo escarnecido en un madero."""
    },
    {
        "id": 429,
        "title": "SEÑOR TU NOMBRE ES INMORTAL",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Señor tu nombre es inmortal
Como la vida eternal
Es inmortal, es inmortal
Porque Tú eres Dios eternal
Los siglos no pasarán
Es sin igual, tu gran deidad.

CORO: Tú eres Dios de amor,
Tú eres eterno Dios, eterno Dios
Señor, quien puede ser como Tú
Mostrarse en gloria de luz
Incomparable, ¡Oh Dios!

2. Señor, tu nombre es sin igual
Tiene dulzura de miel
Como panal, como panal
Y es el hombre como un cantar
Como un remanso al pasar
De aguas puras, de paz.

3. Señor, cuando me alce tu amor
Y junto al trono de Dios
Te vea, te nombre yo
Tu nombre todos alabarán
Los pueblos a Ti cantarán
La gloria, a Jesús darán."""
    },
    {
        "id": 430,
        "title": "ADORACIÓN",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Oh mi Dios, creí que no existías
Que eran fábulas contadas por la gente
Pero sé que Tú eres real
Te siento en mi ser, te quiero hoy contar.

CORO: Aquí están mis manos adorándote
Aquí está mi voz agradeciéndote
Diciendo aleluya, gloria a Dios
Aleluya, aleluya, aleluya,
Gloria a Dios.

2. Ahora sé porque me perdonaste
No querías que yo me perdiera
Humillado reconozco mi error
Soy un pecador, soy un pecador.

3. Él se fue a preparar moradas
Y con ello me ha dado la victoria
Si soy fiel, sé que llegaré, sé que llegaré
Al trono de su Gloria."""
    },
    {
        "id": 431,
        "title": "ES ESPECIAL",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Por las riberas del gran Jordán
Un personaje se hace llamar
Jesús, Jesús, es especial.

CORO: Es especial, es Jesús de Nazaret
Es especial, nadie ha hablado como Él
Es para el ciego como sus ojos
Y al enfermo su sanador
Y a la mujer, como su dulce Salvador.

2. En la montaña resplandeció
Su rostro hermoso transfiguró
Es especial, es el Señor.

3. En el sepulcro no está el Señor
La corrupción no lo alcanzó,
Es especial, Señor y Dios.

4. A la derecha un libro está
Sus siete, sellos los rompió ya,
Es el León, es especial."""
    },
    {
        "id": 432,
        "title": "EL GRAN DÍA DE JEHOVÁ",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Vendrá el Señor en una nube blanca
Y en sus manos la hoz dura traerá
Para segar porque la hora ha llegado
Pues las mies de la tierra ya madura está
Vendrá el Señor como ladrón de noche
Y los impíos dirán a la peña escondednos
De la ira del Cordero
Y de Aquel que en el Trono está.

CORO: Más a vosotros los que
Teméis mi nombre
En la alborada nacerá
El Sol de Justicia
Y saltaréis como becerro
En la manada
Con la potencia del Espíritu
De Dios.

2. Vendrá el Señor, vendrá como relámpago
Y del oriente al occidente se verá
Y será visto por todos los mortales
En el gran día de la gloria de Jehová
Vendrá el Señor y temblará la tierra
Y toda su isla huirá de su lugar
Y los soberbios arderán como la estopa
Serán quemados, así lo ha dicho Jehová."""
    },
    {
        "id": 433,
        "title": "DIOS ME GUARDA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Han pasado los meses y los años
Pero Dios todavía me ha guardado
Han venido vientos y tempestades
Pero Dios todavía me ha guardado.

CORO: ¡Gloria al Señor, hoy puedo decir
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
