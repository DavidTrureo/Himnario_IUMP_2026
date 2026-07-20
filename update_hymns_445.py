import json

new_hymns_data = [
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
Y tan sólo se oye la voz de amor
Que inmensa paz al alma da."""
    },
    {
        "id": 445,
        "title": "YO QUISIERA HABLARTE",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Yo quisiera hablarte del amor de Cristo
Pues en él hallé un amigo fuerte y fiel
Con su muerte transformó mi vida entera
Lo que en esta vida soy lo debo a Él.

CORO: Nadie pudo amarme como Cristo
Es incomparable su amistad
Sólo Él pudo redimirme del pecado
Por su amor y su bondad.

2. Mi alma estaba llena de ayes y tristezas
Llena estaba de miseria y de dolor
Cuando Cristo me tendió su mano tierna
Me guío por el sendero del amor.

3. Cada día viene a darme nuevo aliento,
A mi corazón infunde dulce paz
No comprenderé porque vino a salvarme,
Hasta que en el cielo pueda ver su faz."""
    },
    {
        "id": 446,
        "title": "LAS BODAS DEL CORDERO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Cristo viene pronto a buscar
Cristo viene luego a regalar
Suenan las pisadas franca están
Y en gloria con victoria esperan ya...

CORO: A la cena del Señor convidado estoy
Yo con traje blanco iré,
Lino fino me pondré
Y justificado yo entraré
Y justificado yo entraré / Bis.
Con su sangre yo mi ser limpié
De rodillas a Él aceptó

2. Con su sangre yo mi ser limpié
De rodillas a Él aceptó
Convidado por el Padre fui
Y mi Cristo Salvador fue para mi.

3. En la cena gozo allí habrá
Con blancura celestial será
La esposa al esposo fue
Y el comienzo de la boda ahora es."""
    },
    {
        "id": 447,
        "title": "CUANDO MIRO LOS CIELOS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Cuando miro los cielos y la tierra
Y contemplo el paisaje de la mar,
Por las noches contemplo las estrellas
Por las mañanas de las aves oigo el trinar.
Cuando miro el sol que asoma
Por las colinas
Y me admiro de lo que mi Dios creó.
Es que tengo que decir desde mi alma
Como mi Dios, no hay Dios, como mi Dios.

2. Unos adoran a dioses de madera
Otros de yeso y alma de metal,
Que no oyen ni tampoco hablan
Como no andan los tienen que cargar.
Más mi Dios tiene su trono allá en los cielos
Y es un Dios trino que contesta la oración,
A la presencia del Señor tiembla la tierra
Como mi Dios, no hay Dios, como mi Dios.

3. Cuando Elías se enfrentó a los profetas
Que pedían fuego a Baal
Herían sus pechos y hasta se sangraban
Más no vieron de su Dios fuego bajar.
Más Elías muy sereno miró a los cielos
Y en su confianza fuego a Dios pidió
Rápidamente de los cielos bajo el fuego
Como mi Dios, no hay Dios, como mi Dios."""
    },
    {
        "id": 448,
        "title": "MÁS ALLÁ DE LA AZUL INMENSIDAD",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Más allá de la azul inmensidad
Hay un reino preparado para ti
Las estrellas en su eterno titilar
Ellas denuncian una gloria sin igual.

CORO: Ven, ven pecador
Al reino del amor
Do Jesús te espera en la mansión
Junto al Padre en eterna comunión.

2. Si la tierra está llena de su gloria
Quién es el hombre
Para que aún no crea en Él
Si las olas se levantaran, Él las calma
Y sumisas obedecen a su rey.

3. Si deseas vida eterna alcanzar
Y morar en la patria celestial
No deseches do Jesús llamando está
Más allá de la azul inmensidad."""
    },
    {
        "id": 449,
        "title": "SUPLICA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Vengo a suplicarte mi Señor
Que me dejes reposar
En tu amante pecho mi Señor
Como el Apóstol Juan.

CORO: Me has dado tantas cosas,
Mi precioso Jesús
Me has dado fe, me has dado paz,
Me has dado amor
Me has dado gozo eternal
En plenitud
Me has dado tantas cosas,
Mi precioso Jesús
Que yo sería ingrato, si negara
Tu amor.

2. Cuando estoy Señor ante tu altar
Me conmueve el corazón
Al verte clavado en esa cruz
Por mis culpas y mi error."""
    },
    {
        "id": 450,
        "title": "ES JESUCRISTO MI AMIGO MEJOR",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Es Jesucristo mi amigo mejor
Tierno y amante cual otro no habrá
Toda mi vida descansa en su amor
Tan sólo en Él seguro estaré.

CORO: Oh dulce amigo cerca de ti,
Tus sendas quiero firme seguir
Sentir yo quiero que more en mi
Tu santa gracia para vivir.

2. Venid cantemos a nuestro Señor
Glorioso Cristo que me da salvación
Toda mi vida me guarda en su amor
Tan sólo en Él seguro estaré.

3. Es Jesucristo mi amigo mejor
Es el camino de vida y amor
En este mundo me guarda en su amor
Tan sólo en Él seguro estaré."""
    },
    {
        "id": 451,
        "title": "EL QUE HABITA AL ABRIGO DE DIOS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. El que habita al abrigo de Dios
Morará bajo sombras de amor
Sobre Él no vendrá ningún mal
Y en sus alas feliz vivirá.

CORO: Oh yo quiero habitar
Al abrigo de Dios
Solo allí encontraré paz
Y profundo amor
Mi delicia es con Él,
Comunión disfrutar
Y por siempre su nombre alabar.

2. El que habita al abrigo de Dios
Ciertamente muy feliz será
Ángeles guardarán su salud
Y sus pies nunca resbalarán.

3. El que habita al abrigo de Dios
Para siempre seguro estará
Caerán mil y diez mil por doquier
Más a Él no vendrá mortandad."""
    },
    {
        "id": 452,
        "title": "PIES QUE ANDUVIERON",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Pies que anduvieron en Judea,
Están conmigo
Mano que a Pedro levantó, mi alma tocó
Voz que alentó a la multitud
A mi me ha hablado
Sangre fluyente del costado me lavó.

2. Tengo mi mano en la mano del Señor
Tengo mi mano en la mano del Señor
Y aunque esté en el mundo vil
De pecado y de dolor
Tengo mi mano en la mano del Señor.

3. Al cielo he salido y en su camino estoy
Y cerca cada día más cerca de Él estoy
Cuando en las calles de oro ande yo
Donde los años nunca más se contarán
Me gozaré, y en Él confié
Y la tormenta pasé
Tendré mi mano, en la mano del Señor."""
    },
    {
        "id": 453,
        "title": "SIN TI",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Tú creaste Señor el mar y la tierra,
Tú creaste Señor, el sol y las estrellas,
Tú creaste también la naturaleza
Y mi vida también, Tú la creaste
(Hermanos)
Es por eso Señor, que mi alma te alaba,
Porque sé que eres Tú, el Dios
Que me guarda.
(Hermanas)
Cuando triste yo estoy, Tú me levantas
No hay nada más grande en el mundo
Que tu poder

CORO: (Todos)
Sin Ti (sin Ti), sin Ti Señor (Señor)
Señor yo no puedo vivir
Si no estás en mi
Tu amor (tu amor),
Tu amor Señor (Señor)
Ha llenado mi vida,
Mi ser y mi corazón
Reconozco señor que sin Ti
No puedo vivir.

2. Necesito de Ti Señor, a cada instante,
Necesito Señor, poder expresarte
Lo que has hecho por mi,
¡Es algo muy grande!
Mientras viva quiero alabarte.
(Hermanos)
Tú eres Señor, lo más grande en mi vida,
Conmigo Tú estás de noche y de día
Yo sé que Tú vives y estás a mi lado,
Te amo, te quiero y te alabo
Mi Rey de amor."""
    },
    {
        "id": 454,
        "title": "DESCIENDE, DESCIENDE",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Como puedo explicar lo que sintieron
Unos hombres tiempo atrás
Como puedo explicar lo que sintieron
Cuando se dieron cuenta
//Que hablaban en lenguas//
Que la promesa de Jesús
Se había cumplido
Y el Espíritu Santo había descendido
Y que estaría con nosotros hasta el fin
Y hoy está aquí, y hoy está aquí.

CORO: Desciende, desciende
Como lenguas de fuego
Como carbón ardiente,
Como Isaías unge mis labios
Para decirle a la gente,
Que Tú estás presente
Desciende, desciende
Como lenguas de fuego
Como carbón ardiente.

2. Hoy puedo saber lo que se siente
Cuando está Tú presencia
Es tan especial, que explicarlo
Con mis palabras cuesta
Pues todo lo cambia, todo lo llena
Suceden cosas que parecen extrañas
Los hombres hablan lenguas,
Los enfermos sanan
Y esa promesa permanece fiel aún
//Y hoy está aquí//."""
    },
    {
        "id": 455,
        "title": "MORA EN MI VIDA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Hoy te siento Señor,
Muy dentro de mi vida,
Y no puedo dejar de sentirte otra vez
Mientras tenga yo vida.
Porque grande es... el poder
Que rebasa en mi corazón,
Y con el me haces ver,
Que no vuelva a caer,
¡Tú me cuidas Señor!

CORO: ¡Grande precio pagaste
En esa cruz... por mi un día!
Con tu sangre lavaste,
Con tus llagas curaste
Mis heridas.
Cómo he de pensar,
En quererte soltar
¡Si Tú me guías!
Porque eres mi razón de vivir
Es por eso que te quiero decir:
¡Mora en mi vida!

2. Reconozco Señor
Que Tú amor garantiza
Paz y seguridad que no podía hallar
Pues, no te conocía.
Y a mi encuentro... llegaste Tú,
Me cubriste en tu manto de amor,
Me compraste Señor
Con la sangre que hoy
Lava mi corazón."""
    },
    {
        "id": 456,
        "title": "HOY DÍA VI",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Hoy día vi nuevamente esa cruz
Está vacía porque vive mi Jesús,
Mi Jesús.

2. Está aquí, tú no lo ves
Pero lo siento muy dentro de mi ser
De mi ser.

CORO: Yo le alabaré con todo el corazón
Porque Jesús me dio la salvación
La gloria es para Jesús
Aleluya al cordero de Dios
Está aquí, lo siento en mi corazón
Está aquí, el Dios de la salvación
Está aquí, dentro de mi
Está aquí, está aquí está aquí.

3. Hoy yo clame, Jesús respondió
Y mis pecados y tristezas se llevó,
Se llevó.

4. Y me llenó con su poder
Y hoy lo siento muy dentro de mi ser,
De mi ser."""
    },
    {
        "id": 457,
        "title": "QUE LINDO",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Sólo al pensar que hay un Dios
Mi alma se regocija
Porque ha llenado mi alma
De esa paz y esa calma
Que el mundo no la da.
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
