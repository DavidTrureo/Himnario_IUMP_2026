import json

new_hymns_data = [
    {
        "id": 457,
        "title": "QUE LINDO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Sólo al pensar que hay un Dios
Mi alma se regocija
Porque ha llenado mi alma
De esa paz y esa calma
Que el mundo no la da.

CORO: ¡Qué lindo, es su mirar!
¡Qué lindo cuando Él habla
A mi alma!
¡Qué bello es andar con Él!
Porque estando con Él,
Nada me faltará.

2. Él me ama, yo le amo también
Y junto a Él, me siento confiado
Y si tú te sientes solo
Yo te brindo ese amor
Que es Cristo, el Salvador."""
    },
    {
        "id": 458,
        "title": "NO SÉ PORQUE",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. No sé porque, Señor ¿Tú me tocaste?
No sé por qué, ¿En mí Tú te fijaste?
Pero si sé, que es grande tu amor por mi.
Mi corazón está agradecido
Mi corazón está a Ti rendido,
Contigo siempre quiero Señor estar.

CORO: Porque fuera de Ti,
Nada deseo en la tierra
Tu presencia es más hermosa
Que cualquier cosa...

2. Me has librado de la muerte
Me has dado nueva vida
Desataste mi tristeza
Me ceñiste de alegría.
Por tanto nunca callaré,
A Ti cantaré, te alabaré, Gloria mía...
Cristo mi señor,
A Ti cantaré, te alabaré
Gloria mía."""
    },
    {
        "id": 459,
        "title": "CONSAGRADO A Ti",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Toma mi vida Señor
Y hazla de nuevo
Límpiame de toda maldad, con tu sangre
Llena mi vida y mi ser
De tu amor
Líbrame de mi voluntad, con tu espíritu
Sáname de mi vanidad, Señor.

CORO: Rodéame, no permitas
Que me aleje de Ti, oh Dios
A Tú lado, soy feliz, feliz;
Cúbreme, en tus alas estaré seguro
Y al final de la jornada
A tus brazos volaré.

2. Llena mi copa Señor
Dame tu fuego
Y cuando me falte la fe, Dios ayúdame
Nunca se aparte de mí, tu perdón
Cuida mis pasos Señor,
Recto quiero andar
Llévate de mí la impiedad, Señor.
Y al llegar a tu presencia
Tu hermosura contemplaré
Es mi anhelo, es mi anhelo."""
    },
    {
        "id": 460,
        "title": "ALABA A DIOS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Dios, no rechaza oración,
Oración es alimento.
Nunca vi un justo sin respuesta.
O quedar en sufrimiento.
Basta solamente esperar,
Lo que Dios irá a hacer
Cuando Él levanta sus manos,
Es hora de vencer.

CORO: Oh, alaba: simplemente alaba
Si estás llorando, alaba.
En la prueba, alaba.
Si estás sufriendo, alaba.
No importa, alaba
Tu alabanza El escuchará.
Dios va al frente, abriendo caminos,
Quebrando cadenas, sacando espinas
Manda a sus ángeles, contigo a luchar
Él abre puertas, nadie puede cerrar;
Él trabaja para los que confían
Camina contigo, de noche y de día
Levanta tus manos, tu victoria llegó
Comienza a cantar y alaba a Dios.
Alaba a Dios, alaba a Dios
Alaba a Dios.

2. La gente necesita entender,
Lo que Dios está hablando,
Cuando Él queda en silencio,
Es porque está trabajando.
Basta solamente esperar
Lo que Dios, ira a hacer
Cuando Él extiende sus manos...
Es hora de vencer."""
    },
    {
        "id": 461,
        "title": "BAUTÍZAME",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Señor haz de mi vida
Un instrumento afinado
Quiero sentirte Jesús,
Con poder y entusiasmo.
Pero me falta Señor,
Que me arropes con tu manto
Derrama en mi, tu poder
Sopla tu Espíritu Santo.

CORO: Bautízame, bautízame, bautízame,
Con tu Espíritu Santo;
Quiero sentir tu presencia
Que desciende de lo alto.
Bautízame, bautízame, bautízame,
Con tu Espíritu Santo;
Llena mi copa Señor, hasta
Que esté rebosando.

2. He prometido Señor,
Servirte todos los años,
Quiero contarle a las almas
Como me has transformado,
Anunciarle que regresas
Y en tu nombre hacer milagros
Derrama en mi tu poder
Sopla tu Espíritu Santo."""
    },
    {
        "id": 462,
        "title": "EN TI CONFIARÉ",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Sólo en Dios tu debes confiar
Sólo en Él debes esperar
Como muchos que esperaron su promesa
Permanece siempre fiel
Porque sé Que sólo Él
No tardará en responder
Tu necesidad.

CORO: Sólo debes confiar
Y Él te ayudará
Su promesa es fiel
Y no te dejará
Porque sé
Que en mi Dios
Seguro estarás
Sólo en Él tú debes confiar.

2. Si aún dudas de Él
De su amor y de su poder
No te olvides
Que a la muerte Él venció
Yo sí sé, que es real
Y su amor no tiene igual
Y aunque esté en aflicción
Será más grande
Será más grande
Mi bendición.

CORO 2: Sólo en Ti confiaré
Porque Tú eres mi Dios
Yo no he de temer
Mi confianza está en Ti
Fortaleza será
Cuando débil esté
Esperanza bendita
Sólo en Ti confiaré."""
    },
    {
        "id": 463,
        "title": "LA IGLESIA DEL SEÑOR",
        "tone": "TONO: DO / 2 TIEMPOS",
        "lyrics": """1. La iglesia del Señor, ¿cuál será?
Es aquella que en el nombre del Señor,
Sana enfermos, echa fuera demonios,
Es aquella que rescata al pecador,
Esa, si, es la iglesia del Señor."""
    },
    {
        "id": 464,
        "title": "CUANDO VENGA EL SEÑOR",
        "tone": "TONO: DO / 2 TIEMPOS",
        "lyrics": """1. Cuando venga el Señor,
Y te pregunte por tu talento,
¿Qué dirás al Señor,
Del talento que Cristo te dio?
Multiplícalo, multiplícalo,
Multiplica, hermano, tu talento,
El talento que Cristo te dio."""
    },
    {
        "id": 465,
        "title": "CUANDO CRISTO VENGA",
        "tone": "TONO: SOL 2 TIEMPOS",
        "lyrics": """1. Cuando Cristo venga en las nubes,
Cuando Cristo venga no habrá más dolor.
Cuando Cristo venga en su gloria,
Juntos estaremos con el Salvador."""
    },
    {
        "id": 466,
        "title": "ME PREGUNTAS",
        "tone": "TONO: RE / 2 TIEMPOS",
        "lyrics": """1. Me preguntas ¿por qué amo a Cristo,
A Cristo, a Cristo?
Te lo voy a revelar.
Es porque al dejar su hogar celeste
Murió por mi,
Y no puedo menos yo que amarle,
Pues Jesús murió por mí."""
    },
    {
        "id": 467,
        "title": "SIEMPRE ACOMPAÑADO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Siempre acompañado voy con Jesús
Siempre acompañado voy con Jesús
Él con voz tierna y suave,
Habla a mi alma así:
¡No te dejo solo! Voy con Jesús."""
    },
    {
        "id": 468,
        "title": "MÁS ALLÁ",
        "tone": "TONO: RE / 2 TIEMPOS",
        "lyrics": """1. Más allá, mi nombre escrito está,
Más allá, mi nombre escrito está
Con letras de oro escrito está.
Escrito está, escrito está,
Con letras de oro escrito está
Mi nombre más allá."""
    },
    {
        "id": 469,
        "title": "CRISTO ES SIN IGUAL",
        "tone": "TONO: LA / TIEMPOS",
        "lyrics": """1. Cristo es sin igual, sin igual, sin igual,
Cristo es sin igual para mi;
No hay otro Salvador, no hay otro Sanador,
Cristo es sin igual para mi."""
    },
    {
        "id": 470,
        "title": "YO ESTOY CONTENTO",
        "tone": "TONO: RE / 2 TIEMPOS",
        "lyrics": """1. Yo estoy contento, porque soy de Cristo,
Yo estoy contento, porque soy de Cristo,
Yo estoy contento, porque soy de Cristo,
Aquí y en la eternidad.
Yo he nacido para alabar al Cordero,
Yo he nacido para alabar al Cordero,
Yo he nacido para alabar al Cordero,
Aquí y en la eternidad."""
    },
    {
        "id": 471,
        "title": "ALELUYA AL CORDERO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Aleluya al cordero
Aleluya al cordero
Déjate guiar
Y entrarás al cielo."""
    },
    {
        "id": 472,
        "title": "MUY POCO TIEMPO ESTUVO CRISTO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Muy poco tiempo estuvo Cristo
En la tierra
Y muchos fueron los beneficiados
Y cuando venga para ser glorificado,
Dirán los redimidos gloria a Dios,
Gloria a Dios."""
    },
    {
        "id": 473,
        "title": "SANTIDAD RECLAMA CRISTO",
        "tone": "TONO: RE / TIEMPOS",
        "lyrics": """1. Santidad reclama Cristo
De los suyos, santidad,
Santidad; santidad,
Él no quiere que vivamos
Una vida de pecar,
Eso no quiere Dios
Santidad, santidad,
Eso, sí, quiere Dios.
Santidad, santidad,
Eso, sí, quiere Dios."""
    },
    {
        "id": 474,
        "title": "CUANDO EL ALMA ESTÁ LLENA DE AMOR",
        "tone": "TONO: RE / 2 TIEMPOS",
        "lyrics": """1. Cuando el alma está llena de amor,
Cuando el alma está llena de amor,
Es muy fácil orar durante el día y cantar,
Cuando el alma está llena de amor.
Cuando el alma está triste y vacía,
Cuando el alma está triste y vacía,
Es difícil orar durante el día y cantar,
Cuando el alma está triste y vacía."""
    },
    {
        "id": 475,
        "title": "CRISTO ES LA PEÑA",
        "tone": "TONO: RE / TIEMPOS",
        "lyrics": """1. Cristo es la peña de Horeb
Que está brotando
Agua de vida saludable para mi.
Ven a beber, es más dulce que la miel.
Refresca el alma,
Satisface nuestro ser.
Cristo es la peña de Horeb
Que está brotando
Agua de vida saludable para mi."""
    },
    {
        "id": 476,
        "title": "QUÉ GLORIOSO ES ANDAR CON ÉL",
        "tone": "TONO: RE / 2 TIEMPOS",
        "lyrics": """1. ¡Qué glorioso es andar con Él!
¡Qué glorioso es andar con Él!
Él mis pasos guiará
Y al fin me llevará.
¡Qué glorioso es andar con Él!"""
    },
    {
        "id": 477,
        "title": "HAY VIDA EN JESÚS",
        "tone": "TONO: MI / 2 TIEMPOS",
        "lyrics": """1. Hay vida, hay vida en Jesús,
Hay vida, hay vida en Jesús.
Yo voy a morar a la Patria Celestial
Porque hay vida, hay vida en Jesús.

2. Hay gozo, hay gozo en Jesús,
Hay gozo, hay gozo en Jesús.
Yo voy a morar a la Patria Celestial
Porque hay gozo, hay gozo en Jesús.

3. Hay triunfo, hay triunfo en Jesús,
Hay triunfo, hay triunfo en Jesús.
Yo voy a morar a la Patria Celestial
Porque hay triunfo, hay triunfo en Jesús.

4. Hay vida, gozo y triunfo en Jesús,
Hay vida, gozo y triunfo en Jesús.
Yo voy a morar a la Patria Celestial
Porque hay vida, gozo y triunfo en Jesús."""
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
