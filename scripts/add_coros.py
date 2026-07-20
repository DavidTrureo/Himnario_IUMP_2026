#!/usr/bin/env python3
import json

def add_coros():
    with open('assets/json/coros.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    existing_titles = {h['title'].strip().upper() for h in data}
    last_id = max(h['id'] for h in data) if data else 0
    next_id = last_id + 1

    new_coros = [
        {
            "title": "REGOCÍJATE Y CANTA",
            "tone": "Em",
            "lyrics": "1\n//Regocíjate y canta\nOh, moradora de Sión//\nPorque grande es,\nPorque grande es,\nPorque grande es\nEn medio de ti el Santo de Israel"
        },
        {
            "title": "ORANDO SIN CESAR",
            "tone": "G",
            "lyrics": "1\n//Orando sin cesar, venceremos//\nPara poder vencer, necesitas el poder\n//Orando sin cesar, venceremos//\n\n2\nVenceré, porque Él está conmigo,\nVencerás porque es tu Amigo fiel\nVenceré, venceré,\nVencerás, vencerás,\nVenceremos en el nombre del Señor"
        },
        {
            "title": "JEHOVÁ LE DIJO AL PROFETA",
            "tone": "A",
            "lyrics": "1\nJehová le dijo al profeta:\n¿Estos huesos vivirán?\nEl profeta le respondió:\nTu lo sabes, mi Señor\n\nCoro:\n///Estos huesos, vivirán///\nTu lo sabes, mi Señor"
        },
        {
            "title": "DIOS, DIOS MIO ERES TU",
            "tone": "G",
            "lyrics": "1\n//Dios, Dios mio eres tu,\nDe madrugada te buscaré//\n\n2\nMi alma tiene sed de Ti\nY mi carne te anhela,\nEn tierra seca y árida\nDonde agua no hay"
        },
        {
            "title": "CRISTO NOMBRE GLORIOSO",
            "tone": "D",
            "lyrics": "1\nCristo, nombre glorioso,\nPrecioso Salvador,\nBello Señor,\nEmanuel, Dios con nosotros,\nPalabra viva, mi Redentor"
        },
        {
            "title": "HOY YO SIENTO GOZO",
            "tone": "G",
            "lyrics": "1\nHoy yo siento gozo\nAl saber que todos\nLos que están presentes,\n¡Son hijos del Rey!\nPero si alguno\nTodavía no ha llegado\nA los pies de Cristo\nPuede hacerlo hoy\n\nCoro:\n//Ven, ven, ven\nA Jesús, tu ven//\n\n2\nAmigo date prisa\nPorque el tiempo es corto,\nJesucristo viene,\nPrepárate ya\nPero si alguno\nTodavía no ha llegado\nA los pies de Cristo\nPuede hacerlo hoy"
        },
        {
            "title": "JESUCRISTO REINA",
            "tone": "Em",
            "lyrics": "1\n///Jesucristo reina, reina ya///\n///Aleluya, amén///\n\n2\n///Jesucristo sana, sana ya///\n///Aleluya, amén///\n\n3\n///Jesucristo salva, salva ya///\n///Aleluya, amén///"
        },
        {
            "title": "NO HAY SALUDO MAS BONITO",
            "tone": "Em",
            "lyrics": "1\nNo hay saludo más bonito,\nQue el saludo del cristiano\n\n2\nTe da la mano y te dice:\n“Dios te bendiga, mi hermano”\n\nCoro:\n///Dios te bendiga///\nMi hermano"
        },
        {
            "title": "YO TE ALABARÉ, SEÑOR",
            "tone": "C",
            "lyrics": "1\nYo te alabaré, Señor,\nCon todo el corazón\n\n2\nY en presencia de los ángeles\nA ti, yo cantaré ¡Loores!"
        },
        {
            "title": "ESPIRITU DE DIOS",
            "tone": "Am",
            "lyrics": "1\nEspíritu de Dios,\nLlena mi vida, llena mi alma,\nLlena mi ser\n\nCoro:\nLléname, lléname,\nCon tu poder,\nLléname, lléname,\nCon tu amor,\nLléname, lléname,\nCon tu bondad…"
        },
        {
            "title": "CUANDO VENGA EL SEÑOR",
            "tone": "Am",
            "lyrics": "1\nCuando venga el Señor de los cielos,\nEstés vivo o estés muerto,\n¿Que cuenta le darás?\n\n2\nAmigo ya no peques más,\nJesús te dice: “Ven a mi”.\nRecuerda que es tu Salvador\nNunca se olvidará de ti…\nOh, vienen los ángeles,\nVienen los ángeles\nA dejar al Rey…"
        },
        {
            "title": "COMO LADRON EN LA NOCHE",
            "tone": "Em",
            "lyrics": "1\n//Como ladrón en la noche//\nAsí será la venida,\nLa venida del Hijo del hombre,\nAsí lo dice la bilbia,\nLa biblia no puede mentir…\n//Que su venida será\nComo ladrón en la noche//"
        },
        {
            "title": "EL AMOR DE DIOS ES MARAVILLOSO",
            "tone": "D",
            "lyrics": "1\n///El amor de Dios es maravilloso///\nQue grande es el amor de Dios\n\nCoro:\nTan alto que no puedo ir arriba de él,\nTan bajo, que no puedo ir abajo de él,\nTan amplio que no puedo\nSalirme de Él\nQue grande es el amor de Dios"
        },
        {
            "title": "ME PREGUNTAS PORQUE AMO AL SEÑOR",
            "tone": "D",
            "lyrics": "1\nMe preguntas porque amo al Señor\nY yo respondo: “Debo mucho a mi Dios”\n\n2\nEstando enfermo, Él me vino a sanar,\nEstando triste, Él me vino a consolar,\nTrajo alegría, a mi ser le dio la paz,\nCorona hermosa en el cielo me dará"
        },
        {
            "title": "MARAVILLOSO ES MI JESÚS",
            "tone": "D",
            "lyrics": "1\nMaravilloso es mi Jesús,\nRey de paz, Rey de amor,\nMaravilloso es Jesús\n\n2\nMe levantó del valle de los muertos\nY allí subiome al monte de su gloria\nY allí cantaré la canción\nQue hay en mi corazón:\n“Maravilloso es Jesús”"
        },
        {
            "title": "YO SOY TESTIGO DEL PODER DE DIOS",
            "tone": "C",
            "lyrics": "1\nYo soy testigo del poder de Dios,\nMuchos milagros Él ha hecho en mi,\nYo era ciego y ahora veo la luz,\nLa luz bendita que me da Jesús.\n\n2\nComo la viuda que dio lo que tenía,\nLa última blanquita la dio para el Señor;\nHermano mío, si das lo que tú tienes,\nRecibirás del cielo bendición\n\nCoro:\nBendición, bendición recibirás de Dios\nSi confías en las promesas del Señor\nCristo sana, salva y bautiza con poder,\n¡Aleluya, gloria a Dios!"
        },
        {
            "title": "ALABARÉ, ALABARÉ",
            "tone": "G",
            "lyrics": "Coro:\nAlabaré, alabaré,\nalabaré, alabaré,\nalabaré a mi Señor.\n\n1\nJuan vio el número\nde los redimidos\ny todos alababan al Señor.\nUnos oraban,\notros cantaban,\ny todos alababan al Señor."
        },
        {
            "title": "SEÑOR TE ALABO",
            "tone": "G",
            "lyrics": "1\n///Señor te alabo///\nCon todo mi ser\n\n2\n///Esclavo fui, mas, tú me libraste///\n¡Señor te alabo,\nCon todo mi ser!"
        },
        {
            "title": "VAMOS CANTANDO",
            "tone": "G",
            "lyrics": "1\n//Vamos cantando hasta que baje el poder//\nLa gloria a Él, la gloria a Él,\nVamos cantando hasta que baje el poder\n\n2\n//No te avergüences y alaba a tu Señor//\nLa gloria a Él, la gloria a Él,\nNo te avergüences y alaba a tu Señor\n\n3\n//Salta cordero y alaba a tu Señor//\nLa gloria a Él, la gloria a Él,\nSalta cordero y alaba a tu Señor\n\n4\n//Toma la biblia y sal a predicar//\nLa gloria a Él, la gloria a Él,\nToma la biblia y sal a predicar\n\n5\n//Toma tu himnario y cántale al Señor//\nLa gloria a Él, la gloria a Él,\nToma tu himnario y cántale al Señor"
        },
        {
            "title": "CAMINANDO VOY",
            "tone": "G",
            "lyrics": "1\n///Caminando voy para Canaán///\nGloria a Dios, Caminando voy para Canaán///\n\n2\n///Si usted no va, no me impida a mi///\nGloria a Dios, Caminando voy para Canaán\n\n3\n///Al venir Jesús, yo me voy con Él///\nGloria a Dios, Caminando voy para Canaán"
        },
        {
            "title": "DULCE REFUGIO",
            "tone": "C",
            "lyrics": "1\nDulce refugio \nEn la tormenta \nEs Jesucristo \nEl salvador. \n\nÉl me alienta \nY me alimenta \nCon su palabra \ny su amor. \n\nCoro:\nVengo a reposar en el\nÉl es mi amigo fiel\nUna poderosa y fresca unción\nLlenará mi corazón.\n\nDulce refugio\nEn la tormenta\nEs Jesucristo\nEl salvador.\n\nFinal:\n//Es Jesucristo \nel salvador//"
        },
        {
            "title": "GRANDE AMOR",
            "tone": "A",
            "lyrics": "1\nGrande amor,\nProfundo amor,\nPerfecto amor,\nEl de Cristo Jesús,\nPara mi\n\n2\nNo lo puedo entender,\nPero Él me ama,\nNo lo comprendo,\nPero Ël me suplirá,\nTodo mi ser se llena de Él\nPorque profundo\nY perfecto es su amor"
        },
        {
            "title": "ALABAD A JEHOVÁ",
            "tone": "G",
            "lyrics": "1\nAlabad a Jehová,\nNaciones todas,\nPueblos todos,\nAlabadle.\nPorque ha engrandecido\nSobre nosotros su misericordia,\n\nCoro:\nY la verdad de Jehová\nEs para siempre,\n¡Aleluya, amén!\nY la verdad de Jehová\nEs para siempre,\n¡Aleluya, amén!"
        },
        {
            "title": "YO ME GOZO",
            "tone": "C",
            "lyrics": "1\nYo me gozo el Lunes,\nYo me gozo el Martes,\nYo me gozo el Miércoles,\n\n2\nYo me gozo el Jueves,\nYo me gozo el Viernes,\nYo me gozo el Sábado,\n\n3\nY al llegar Domingo,\nSigo con mi gozo\nY te diré por qué:\n\nCoro:\n“Porque tengo a Cristo,\nQue me da la vida\nY que me da poder”"
        },
        {
            "title": "DIOS ESTA AQUÍ",
            "tone": "",
            "lyrics": "1\n//Dios está aquí,\nQue precioso es,\nÉl lo prometió\nDonde hay dos o tres//\n\nCoro:\nQuédate Señor,\nQuédate Señor,\nQuédate Señor,\nEn cada corazón\nQuédate Señor,\nQuédate Señor,\nQuédate Señor,\nAquí\n\n2\nOh, Cristo mío,\nHas en mi alma un altar,\nPara adorarte,\nCon devoción,\nPara beber\nDel agua de la vida\nY así saciar\nSiempre mi corazón"
        },
        {
            "title": "EBEN-EZER",
            "tone": "",
            "lyrics": "1\nEben-Ezer, hasta aquí\nNos ayudó Jehová,\nCon su poder\nY su mano nos guiará.\n\nCoro:\nEsta canción que por siglos durará\n¡Eben-Ezer, hasta aquí\nNos ayudó Jehová!"
        },
        {
            "title": "ENCOMIENDA A JEHOVA",
            "tone": "",
            "lyrics": "1\nEncomienda a Jehová tu camino\nY confía en Él,\n//Y Él hará y Él hará//\n\n2\nGuarda silencio ante Dios\nY espera en Él,\n//Y Él hará y Él hará//"
        },
        {
            "title": "HAS CAMBIADO MI LAMENTO",
            "tone": "",
            "lyrics": "1\nHas cambiado\nMi lamento en baile,\nMe ceñiste de alegría,\nPor tanto a ti cantaré\nGloria mía\nY no estaré callado\n\nCoro:\nJehová, Dios mío te alabaré\n¡Te alabaré para siempre!\nPorque has cambiado\nMi lamento en baile,\nJehová, Dios mío\n¡Te alabaré!"
        },
        {
            "title": "LA TRISTEZA",
            "tone": "",
            "lyrics": "1\nLa tristeza puede durar\nHasta el anochecer,\n//Mas, la alegría viene,\nViene al amanecer//\n\nCoro:\n///Quiero despertar cantando///\nY alabando a mi Señor."
        },
        {
            "title": "MIRA LO QUE HIZO MI JESÚS",
            "tone": "",
            "lyrics": "1\n//Mira lo que hizo mi Jesús//\n//Me levantó y me liberó,\nMira lo que hizo mi Jesús//\n\n2\n//Caminando por la senda voy//\n//De prueba en prueba,\nVictoria tras victoria,\nCaminando por la senda voy//\n\n3\n//El enemigo ya vencido está//\n//Jesús lo venció\nMuriendo en la cruz,\nEl enemigo ya vencido está //"
        },
        {
            "title": "NO HAY DIOS TAN GRANDE",
            "tone": "",
            "lyrics": "1\n//No hay dios, tan grande como Tú\nNo lo hay, no lo hay//\n\n2\n//No hay dios que pueda hacer las obras,\nComo las que haces Tú//\n//No es con espada, ni con ejércitos\nMas, con tu Santo Espíritu//\n\nCoro:\n///Y esos montes se moverán///\nMas, con tu Santo Espíritu"
        },
        {
            "title": "SOLAMENTE EN CRISTO",
            "tone": "",
            "lyrics": "1\nSolamente en Cristo,\nSolamente en Él,\nLa salvación\nSe encuentra en Él\n\n2\nNo hay otro nombre\nDado a los hombres\nSolamente en Cristo,\nSolamente en Él"
        },
        {
            "title": "TE ALABARÁN",
            "tone": "",
            "lyrics": "1\nTe alabarán oh, Jehová\nTodos los reyes,\nTodos los reyes de la tierra\n\n2\nPorque han oído\nLos dichos de tu boca\nY cantarán\nDe los caminos de Jehová\n\n3\nPorque la gloria\nDe Jehová es grande\nPorque Jehová\nEs excelso en su camino\nPorque Jehová\nAtiende al humilde\nMas, mira de lejos al altivo"
        },
        {
            "title": "TENDRAS QUE RENACER",
            "tone": "",
            "lyrics": "1\n///Tendrás que renacer///\nEn Cristo.\nSi tú quieres ir\nAl cielo con Jesús\nTendrás que renacer en el Señor\n\nCoro:\nOh, hay que nacer del agua\nOh, hay que nacer del Espíritu de Dios,\n//Oh, hay que nacer\nDel agua y del Espíritu de Dios,\nHay que nacer en el Señor//"
        },
        {
            "title": "UN PALACIO TENGO",
            "tone": "",
            "lyrics": "1\n///Un palacio tengo yo\nMás lindo que el sol///\nEn el más allá\n\n2\n///Si Señor, si Señor,\nAcuérdate de mi///\nEn el más allá\n\n3\n///Oh bendito Cristo\nContigo estaré///\nEn el más allá\n\n4\n///Si tú quieres ir al cielo\nY ver al Señor///\nEn el más allá"
        }
    ]

    added = []
    skipped = []
    
    for coro in new_coros:
        key = coro['title'].strip().upper()
        if key in existing_titles:
            skipped.append(coro['title'])
        else:
            coro['id'] = next_id
            data.append(coro)
            existing_titles.add(key)
            added.append(f"[{next_id}] {coro['title']}")
            next_id += 1

    with open('assets/json/coros.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ Agregados a coros ({len(added)}):")
    for t in added: print(f"   {t}")
    print(f"\n⏭️ Omitidos por duplicados ({len(skipped)}):")
    for t in skipped: print(f"   - {t}")
    print(f"\nTotal coros ahora: {len(data)}")

if __name__ == '__main__':
    add_coros()
