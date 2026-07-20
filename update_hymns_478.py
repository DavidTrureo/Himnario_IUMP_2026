import json

new_hymns_data = [
    {
        "id": 478,
        "title": "ESTOY ALEGRE",
        "tone": "TONO: RE / 2 TIEMPOS",
        "lyrics": """1. Estoy alegre, alegre, muy alegre,
Estoy alegre, porque Cristo me salvó,
Estoy alegre, alegre, muy alegre,
Estoy alegre, porque Cristo me salvó."""
    },
    {
        "id": 479,
        "title": "PERDER LOS BIENES ES MUCHO",
        "tone": "TONO: SOL / 3 TIEMPOS",
        "lyrics": """1. Perder los bienes es mucho.
Perder la salud es más.
Perder el alma es pérdida tal
Que no se recobra jamás."""
    },
    {
        "id": 480,
        "title": "DIOS DE TAL MANERA",
        "tone": "TONO: SOL / 2 TIEMPOS",
        "lyrics": """1. Dios de tal manera
A este mundo amó
Que a su propio Hijo
No se reservó.
Para que cualquiera
Que confiara en Él
Vida eterna tenga
En vez de perdición."""
    },
    {
        "id": 481,
        "title": "CRISTO YA PAGÓ POR MÍ",
        "tone": "TONO: SOL / 4 TIEMPOS",
        "lyrics": """1. Cristo ya pagó por mí,
En la cruz pagó por mí.
Este es mi canto por siempre, sí,
Una cosa grande es
Poseer la salvación
Y saberlo, sí, y mostrarlo, si
Que ya tengo salvación."""
    },
    {
        "id": 482,
        "title": "TENME BRILLANDO",
        "tone": "TONO: RE / 2 TIEMPOS",
        "lyrics": """1. Tenme brillando, Señor,
Tenme brillando por Ti
Puro y limpio seré, si Tú brillas por mi,
Tenme brillando, Señor,
Tenme brillando por Ti
Hasta que vengas pronto con poder.
Oh, llévame a la roca más alta, Señor
Llévame Señor, yo te seguiré
Oh, llévame a la roca más alta Señor
Sólo en Ti refugio tendré."""
    },
    {
        "id": 483,
        "title": "QUE VUELVA ATRÁS",
        "tone": "TONO: SOL / 2 TIEMPOS",
        "lyrics": """1. Que vuelva atrás, que vuelva atrás
Me dice el mundo con toda su maldad
Y yo respondo que ahora voy buscando,
Buscando fe, esperanza y caridad.
Quiero llegar, quiero llegar
A ser un hombre de experiencia espiritual,
Y así el Señor Jesús me irá guiando
Hasta llegar al trono de Jehová."""
    },
    {
        "id": 484,
        "title": "VIENE YA",
        "tone": "TONO: MI / 2 TIEMPOS",
        "lyrics": """1. Viene ya, viene ya,
Mi Jesús ya viene, ya,
Revestido de gloria y majestad
En las nubes mi Jesús viene ya.
Viene ya, viene ya, mi Jesús viene, viene ya
Por su pueblo que ama en verdad
En las nubes mi Jesús viene ya."""
    },
    {
        "id": 485,
        "title": "SEÑOR, TE PEDIMOS CON FERVOR",
        "tone": "TONO: SOL / 2 TIEMPOS",
        "lyrics": """1. Señor, te pedimos con fervor
Que nos des un avivamiento,
Que nos llenes de tu santo amor
Y tu Santo Espíritu.
Señor, te pedimos con fervor
Que nos des un avivamiento.
Que venga aquí que vaya allí,
Que empiece por mí, Señor;
Que venga aquí que vaya allí,
Que siga creciendo en mí."""
    },
    {
        "id": 486,
        "title": "¡OH, CHILE UNA PATRIA REDIMIDA!",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. ¡Oh, Chile, una patria redimida!
Es el lema de nuestra Iglesia fiel,
Levantemos de Cristo la Bandera
Y chilenos transformados se han de ver."""
    },
    {
        "id": 487,
        "title": "QUIERO LEVANTAR MIS MANOS",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Quiero levantar mis manos
Quiero levantar mi voz,
Ofreciendo a Ti mi vida,
En santidad y amor,
Padre sólo a Ti te ofrezco,
Mi vida y mi corazón,
Y me postro en tu presencia,
En adoración.
Hijo de Dios, recibe hoy
Toda la gloria, la honra y honor."""
    },
    {
        "id": 488,
        "title": "HABACUC CAP. 3 VERS. 17-18",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Aunque la higuera no florezca
Ni en las vides haya frutos
Aunque falte el producto del olivo
Y los labrados no den mantenimiento.
Con todo yo me alegraré
Y me alegraré en Jehová
Y me gozaré y me gozaré
En el Dios de mi Salvación."""
    },
    {
        "id": 489,
        "title": "RENUÉVAME",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Renuévame, Señor, Jesús
Ya no quiero ser igual
Renuévame Señor, Jesús
Pon en mi tu corazón
Porque todo lo que hay
Dentro de mi
Necesita ser cambiado Señor
Porque todo lo que hay
Dentro de mi corazón
Necesita más de Ti."""
    },
    {
        "id": 490,
        "title": "HOY MÁS QUE NUNCA",
        "tone": "TONO: / TIEMPOS",
        "lyrics": """1. Hoy más que nunca Señor te necesito
Hoy más que nunca Señor yo te amo
Hoy más que nunca Señor quiero decirte
Te necesito y te amo Señor."""
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

# Sort hymns by ID
hymns.sort(key=lambda x: x["id"])

with open(file_path, "w", encoding="utf-8") as f:
    json.dump(hymns, f, ensure_ascii=False, indent=2)

print("Hymns updated successfully.")
