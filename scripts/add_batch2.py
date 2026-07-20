#!/usr/bin/env python3
import json

with open('assets/json/special_hymns.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

existing_titles = {h['title'].strip().upper() for h in data}
last_id = max(h['id'] for h in data)

new_hymns = [
    {
        "title": "MI REDENTOR VIVE",
        "tone": "G",
        "lyrics": "1\nSé que mi Redentor vive,\nY al fin se levantará;\nSé que mi Redentor vive,\nY al fin sobre la tierra reinara.\nAunque mi carne sea desecha,\nCon mis ojos veré a mi Dios.\n\nCoro:\n//Sé que mi Redentor vive,\nY con Él me levantaré.//\n\n2\nMi corazón desfallece en mí,\nEsperando el regreso de Jesús;\nMi corazón desfallece en mí,\nDeseando que regrese a reinar.\nAunque mi carne sea desecha,\nCon mis ojos veré a mi Dios.\n\nCoro Final:\nSé que mi Redentor vive,\nY con Él me levantaré.\nSé que mi Redentor vive,\nY con Él me levantaré…\nCon Él me levantaré\nCon Él me levantaré\nCon Él me levantaré"
    },
    {
        "title": "DULCE REFUGIO",
        "tone": "C",
        "lyrics": "Dulce refugio\nEn la tormenta\nEs Jesucristo\nEl salvador.\nÉl me alienta\nY me alimenta\nCon su palabra y su amor.\nVengo a reposar en el\nÉl es mi amigo fiel\nUna poderosa y fresca unción\nLlenará mi corazón.\nDulce refugio\nEn la tormenta\nEs Jesucristo\nEl salvador.\n\nFinal:\n//Es Jesucristo el salvador//"
    },
    {
        "title": "BENDECIRÉ TU NOMBRE POR SIEMPRE",
        "tone": "",
        "lyrics": "A la oscuridad dio Luz\nA la nada vida dio\nDesde antes eras Tú\nTu nombre bendeciré\nDios de acuerdo a tu plan\nNos creaste en tu bondad\nPara adorarte y\nBendecir tu nombre Oh Dios\nA este mundo vino Él\nPor su gracia y poder\nMis pecados Él lavó\nTe bendeciré Oh Dios\nA tu trono vengo hoy\nSin nada bueno en mi corazón\nSolo a tí adoraré\nTu nombre bendeciré\n\nCoro:\nTe bendeciré\nTe bendeciré\nTe bendeciré por Siempre Oh Dios\nTe bendeciré\nTe bendeciré\nTe bendeciré por Siempre Oh Dios"
    },
    {
        "title": "EL BUEN PASTOR",
        "tone": "",
        "lyrics": "1\nPerdido andaba yo,\nerrante por el mundo\ninundado en el vacio\nque el pecado me brindo\nComo una oveja descarriada\nsin saber por donde iba\nsin detenerme a contemplar\nla maldad que me atrapaba\n\nCoro:\nPastor de mi corazon\ncon voz fuerte me llamabas\ncuesta arriba, cuesta abajo\nno cansabas en buscarme\ny allí enredado en los espinos\nen el lodo cenagoso del valle de sombras\nme encontraste, me libraste, me limpiaste\ny me amaste...\n\n2\nMis heridas sanas Tú\ncon tu amor y tu ternura\na pesar de las ofensas\nque en mi vida pueda haber\nCon tu amor Tú me perdonas,\ncon tu sangre hoy me limpias,\nes tu gracia que me cubre\ny me hace nuevo hoy\n\nPuente:\nEn momentos de oscuridad\nal tropezar en los escombros de mi vida\nfue cuando el Buen Pastor\nsu vida dió por mi\nextendió su mano y me hizo vivir\n\nFinal:\ny me amaste..."
    },
    {
        "title": "ERES LA LUZ",
        "tone": "",
        "lyrics": "1\nEres la luz de mis ojos\nQue alumbra mi camino,\nFortaleza de mi vida\nY paz para mi alma.\nEres Tú mi gran amigo\nQue siempre esta conmigo,\nTendiéndome tu mano,\nDispuesto para amar…\n\nCoro:\nY si un día me falta tu Amor,\nNo se que haría\nProbablemente me perdería\nEn este mundo de maldad…\n\n2\nEres Tú como el viento\nCuando acaricia mi ser,\nComo ríos de agua viva\nQue calmas Tú mi sed.\nEres la única esperanza\nY también para este mundo\nY yo creo en tus promesas\nVida eterna me darás…"
    },
    {
        "title": "ESPINAS EN SU FRENTE",
        "tone": "",
        "lyrics": "1\nDe tal manera nos amó,\nQue dejó su gloria,\nConociendo cual sería su fin… nació.\nEl nos trajo la victoria,\nUna luz resplandeció\nAl pecado El venció,\nA la muerte derrotó.\nCuando Cristo expiró… cantó victoria…\n\nCoro:\n…¿Quién me apartará de Ti?\nSolo El pudo amarme así,\nEntregándose a la muerte\nPuso espinas en su frente.\nCristo, Cristo, Cristo…\n…Solo El pudo amarme así…\n\n2\n¿Donde estaba yo, Señor?\nCuando me llamaste,\nCuando me dijiste: \"Hijo, ven a Mi…\"\nMi camino sin sentido,\nMi destino era el Seol.\nDonde estaba yo, Señor,\nNo había luz ni sol,\nMe faltaba tu amor, bendito Cristo..."
    },
    {
        "title": "ESPIRITU SANTO",
        "tone": "",
        "lyrics": "1\nAquí esta mi vida\naquí esta mi corazón\ntómalos Señor son tuyos, tuyos\nlleva lo malo que hay en mí\nlimpia mi corazón\ncon tu presencia lléname tu Señor\nlléname tu Señor, Señor\n\nCoro:\nEspiritu Santo yo te invito a entrar\nen mi vida\nque visites mi corazón\ntoma tu el dominio de mi alma\ncon tu presencia, y tu amor...\nSeñor te invito a entrar\nen mi vida\nque visites mi corazón\ntoma tu el dominio de mi alma\ncon tu presencia, y tu amor\n\n2\nte pido buen Señor\nescuches mi clamor\ny asi poder sentir tu presencia,\ntu presencia\nquiero sentirte buen Señor\nen mi corazón en toda mi vida,\ndentro de mi Señor.\ndentro de mi Señor, Señor\n\nFinal:\nEntra en mi vida Señor..."
    },
    {
        "title": "ESTÁS CONMIGO",
        "tone": "",
        "lyrics": "1\nCuantas veces me he encontrado,\nSolo y abandonado\nOtras veces tan cansado,\ntriste, desorientado\nSin saber, que estas tan cerca Tu de mí\n\nCoro:\nSin darme cuenta he caminado,\nY Tu caminas a mi lado.\nQue fortaleces tu mi alma,\nQue nunca me has abandonado.\nQue eres quién me da el consuelo,\nSi la tristeza me ha invadido,\nQue eres quién nunca me ha dejado,\nQue eres Dios y estás conmigo\n\n2\nAhora se que no estoy solo,\n¡Cristo está conmigo!\nSu paso siempre me acompaña\nMe consuela su mirada,\nEs real su existir,\n¡Pues vive en mi!\n\nFinal:\nQue eres Dios y estás conmigo\nQue siendo Dios...\nEstás conmigo."
    },
    {
        "title": "GLORIOSO ENCUENTRO",
        "tone": "",
        "lyrics": "1\nSé que un lugar me espera más allá,\nDonde por siempre alabaré a mi salvador,\nDonde la muerte y rencor allí no entrara,\nPorque mi Cristo la victoria me dará\n\nCoro:\n//Ya no me importa sufrir,\nYa no me importa lo que el hombre\nPueda hacerme Señor\nSi a mi lado Tú vas confiado estoy,\nNo temeré.\nQuiero llegar a aquel lugar\nY poder escuchar tu tierna voz\nEn lo poco has sido fiel\nSobre mucho te pondré,\nEntra siervo fiel.//\n\n2\nGlorioso encuentro será para mí\nBesar las manos de quien murió por mí,\nDonde nada impedirá que yo alabe al señor\nJunto a los ángeles alabaré a mi Salvador\n\nFinal:\nSiervo fiel\n¡Siervo Fiel!"
    },
    {
        "title": "GRAN AMOR",
        "tone": "",
        "lyrics": "1\nGran amor es el que ha dado Dios\nA mi vida y a la humanidad\nBendito Amor es el que transformó mi ser\nEl que me hizo a mí nacer de nuevo...\n\nCoro:\nY me miraste ¡Oh, Señor!\nMe perdonaste ¡Mi Señor!\nNo hubo nadie que dio lo que me diste Tú\nAmor eterno...\n//¿Que hubiera hecho yo? sin tu Amor\nMe habría perdido aquí sin ti Señor\nPero gracias yo te doy\nPor entregarme tu gran Amor.//\n\n2\nSi tú estás sumido en la tristeza\nQuiero que sepas que a tu lado está el Señor\nNo te olvides que su amor te rescató\nDel abismo el te libró, con su mano...\n\nFinal:\nQuisiera en mi existir darte loor\nAmarte con verdad y hasta el fin\nHoy gracias yo te doy\nPor entregarme tu gran Amor."
    },
    {
        "title": "HOY TE CONOCÍ",
        "tone": "",
        "lyrics": "1\nCuantas veces contra Tí blasfemé,\ncuantas veces yo de Tí me reí,\ncuantas veces de Tí necesité,\nsin pensar que tu estabas ahí,\nPero un día tras el mundo yo fuí,\nsin querer en su maldad yo caí,\nno sabía que camino seguir,\npero un día Tú llegaste a mí...\n\nCoro:\nHoy te conocí,\nhoy ya soy feliz,\nya no me atarán\nlas cadenas que me llevaban al mal,\nHoy puedo decir:\n¡¡Dios me perdono!!\nse que gozaré algún día junto a mi Redentor.\n\n2\nYo quisiera Señor que pusieras en mí,\nel deseo de no separarme de Tí,\na tu lado yo sé, que estoy mucho mejor\ny contigo no conozco el dolor...\nHoy el mundo me desprecia por Tí,\nmás no importa, pues así soy felíz,\nte prometo: ¡No dejarte jamás!\ny contigo llegaré hasta el final..."
    },
    {
        "title": "HOY TE PUEDO SENTIR",
        "tone": "",
        "lyrics": "1\nSeñor, hoy puedo entender\nque todo es verdad\ncuando se habla de Ti\nrazón tienen los que cantan a Ti\nme incluyo en ellos, Señor.\n\nCoro:\nOh, Dios hoy te puedo sentir y decir\nque no hay Dios tan bueno como Tú, Señor,\nlo sabe mi corazón sí, hoy lo puedo entender\nhoy conozco tu amor.\nHoy lo se de verdad\ny no puedo callar no se puede vivir sin Ti\n\n2\nSeñor, he visto tanto en Ti,\nque no puedo callar cuanto haz hecho por mi,\nSolo sé que en mi aflicción nunca solo me hallé\nsiempre tu estuviste alli, Señor"
    },
    {
        "title": "JAMÁS ME DEJA",
        "tone": "",
        "lyrics": "1\nNo hay fuerza que pueda igualar\nAl poder de Jesús\nNo hay baya que pueda vencer\nLo que quiera Él logra\nNo hay nada igualable a su amor\nEl no tiene comparación\nMe ha dicho: \"No te dejare, ni te desampararé…\"\n¡¡Lo creo, si lo creo!!\n\nCoro:\nPorque el jamás, jamás me deja\nY porque el nunca me abandona\nSi el día esta nublado,\nSi arrecia la tormenta,\nYo canto al rey de paz de amor,\nPorque el jamás, jamás me deja…\n\n2\nSi en lucha o peligro de muerte\nMe he de encontrar\nLa nube de Dios me protege\nMe cubre del mal\nPues El es mi ayudador\nMe guía por sendas de paz\nMe ha dicho: \"No te dejare, ni te desampararé…\"\n¡¡Lo creo, si lo creo!!\n\nFinal:\nAmén"
    },
    {
        "title": "JESUCRISTO EN MI VIDA",
        "tone": "",
        "lyrics": "1\nCaminaré sin temores,\nCantaré mis canciones,\nVivirá mi alma\nla más dulce emoción,\n¡Oh, emoción!\nPorque estás conmigo,\nporque me inspiras,\nporque tocas mi vida,\n¡Oh, Jesus! vas conmigo\n¡Caminaré contigo!\n\nCoro:\nEres la causa de mi vida, sólo por Ti existo,\n¿Qué sería de mi, si en mi Tú no estuvieras?\nPero estás aquí, estás en mi vida...\n¡Jesucristo!\n\n2\nEl Señor me ha tocado,\nHe sentido su gozo\nY tendré por siempre\nSu ternura y calor\n¡Oh, emoción!\nAsí irás conmigo,\nEres mi amigo,\nEres mi único norte,\nMi razón de existir...\n¡Caminaré contigo!"
    },
    {
        "title": "JESÚS, MI SALVADOR",
        "tone": "",
        "lyrics": "1\nUn estruendo en el Cielo se sintió\nCuando se oyó con fuerte voz de parte de Dios:\n\"…Destruiré a la humanidad por desobedecer…\"\nCon dulce voz, dice Jesús:\n\"…Envíame a Mi, mi Dios y moriré por la humanidad\nQue perdiéndose está por la ignorancia…\"\n\nCoro:\nSolo Jesús se merece toda honra\nSe merece toda gloria\nSolo Jesús, mi Salvador…\nSolo Jesús se merece alabanza\nSe merece toda honra\nSolo Jesús, mi Salvador…\n\n2\nHoy vivimos felices con mi Dios\nGracias a El, que se atrevió a darnos Amor y Salvación,\n¡¡La gloria es para Jesús, nuestro Señor!!\nSolistas:\nPorque eres digno de toda adoración\nEres el único Salvador\nEres mi Señor\nEres mi Señor…\n\nFinal:\n…Mi Señor, mi Señor, mi Salvador…"
    },
    {
        "title": "JESÚS, PARA TI NO HUBO LUGAR",
        "tone": "",
        "lyrics": "1\nLoas en el cielo escuchad,\nLuz en las naciones brillará.\nPastores canten ya,\nun niño viene ya\nAl hombre salvará.\n\nCoro:\nJesús para ti no hubo lugar, un pesebre nada más\nMás en mi corazón tú te puedes quedar, Jesús.\nJesús, aquí tengo un lugar, donde puedes reposar\nY por siempre morar, en mi.\n\n2\nReyes del oriente llegarán,\noro, mirra e incienso le traerán\nEn humildad,\nnació nuestro Señor,\nHoy es navidad."
    },
    {
        "title": "JESÚS, ES MI PASTOR",
        "tone": "",
        "lyrics": "1\nAhora Jesús es mi Pastor,\nSeguro estoy pues El me guarda\nY por delicados pastos me guiará\nConfortará mi alma.\nCuando en valle oscuro yo me encuentro\nY desesperado por salir,\nEl siempre está tomándome la mano\nLlevándome a la luz...\n\nCoro:\nEs el Señor\nMi seguro y fiel ayudador\nNada me faltará,\nY por su gracia vencedor seré,\nPues, El es mi Pastor\n\n2\nAderezas la mesa para mí,\nCon aceite unges mi cabeza\nY con tu presencia me impartes valor\nPara poder seguir.\nTu misericordia y tu verdad\nMe seguirán todos los días\nY viviré confiado en tu palabra\nConfiando cada día..."
    },
    {
        "title": "LA DUDA",
        "tone": "",
        "lyrics": "1\nEsa duda que invade mi mente,\ndel poder de mi Jesús.\nEsa duda que invade mi ser,\nquisiera quitarla y llenarme de Fé...\n\nCoro:\nSi Cristo vive en mi vida,(¿como dudar?)\nsi ha cambiado mi ser...(¿como dudar?)\n¡Si en el dolor me ha respondido!\n¿Como es posible dudar?\n\n2\nYo he visto con estos ojos\nlos prodigios de mi Jesús,\ny si ahora me falta la fé,\nle clamo con ansias ¡Me entrega Poder!\n\n3\nSi tu tienes hoy esa duda\nque confunde tu corazón,\nclama a Cristo, ¡Tiene Poder!\nlevanta los muertos,\nlos ciegos ya ven..."
    },
    {
        "title": "LA ÚLTIMA MILLA",
        "tone": "",
        "lyrics": "1\nSi camino por rectos senderos,\nsi trabajo cumpliendo un deber,\ncuando mi último viaje termine,\nal gran Rey admirable veré.\n\nCoro:\nCuando al tramo postrer llegue al fin,\nde mi vida en camino hacia Él,\nhasta entonces diré soy feliz,\ncuando el último paso yo de.\n\n2\nSi la historia de Cristo proclamo,\nsi perdidas ovejas hallé,\nmostrarame el Señor su grandeza,\ncuando el último paso yo de.\n\n3\nCaros lazos habrán de ser rotos,\ncon gemidos de angustia al partir,\nmás todo eso será pasajero,\ncuando en la última milla yo esté."
    },
    {
        "title": "LAS AVES DEL CIELO",
        "tone": "",
        "lyrics": "1\nLas aves del cielo,\nsin comprender\ncantan al Dios creador.\nEl ha formado sus vidas,\nlas alimenta también\n\nCoro:\nMas, yo ¿cómo no he de cantarte a Tí?,\nsi soy hechura de tus manos,\npusiste en mi cinco sentidos\ny un corazón\npara poderte amar\nBendita cruz donde Jesus murió por mi,\nvino a salvar lo que El creó\n\n2\nTu eres hecho a la imagen de Dios\ny Dios de los cielos es perfecto.\nMira, cuida tus pasos donde vas,\nsigue a Jesús que te ha dado vida y luz"
    },
    {
        "title": "MAESTRO",
        "tone": "",
        "lyrics": "1\nMaestro, tu que ibas por los montes\nPor quebradas y collados, predicando el Evangelio\nY en las noches el cielo era tu techo,\nY tu almohada una roca y una fogata era el calor.\nY el sustento de comer era tu Poder y Fe,\nEse Poder que alimento a cinco mil…\n\nCoro:\n…Maestro, el Señor es mi Maestro.\nYo de El pude aprender a amar y perdonar,\nY a confiar en su poder.\nMaestro, tu dolor me enseño,\nPara que hoy día yo, pueda ser un buen obrero\nCon poder y con virtud…\n¡Te quiero Maestro!\n\n2\nMi Maestro es señalado entre diez mil\nPor su belleza inconfundible y su glorioso resplandor.\nEl es bello, es glorioso, es eterno\nBondadoso, es perfecto, así es mi Salvador\nSu poder no tiene límite alguno, levanta muertos, sana enfermos\nY aún mas, ¡Limpia el Alma!\n\n3\nMi Maestro es mi fiel consolador\nEn las pruebas y dolor es mi amigo inseparable\nY mi \"Amigo\", también es tu amigo\nEs el que su vida dio en la cruz por nosotros,\nEs aquel que con su sangre me lavó,\nPero ahora está esperando para llevarme con El…"
    },
    {
        "title": "ME DICE QUE ME AMA",
        "tone": "",
        "lyrics": "1\nMe dice que me ama\nCuando escucho llover,\nme dice que me ama\ncon un atardecer\nLo dice sin palabras,\ncon las olas del mar,\nLo dice en la mañana\ncon mi respirar...\n\nCoro:\nMe dice que me ama y que conmigo quiere estar,\nEl dice que me busca cuando salgo yo a pasear,\nQue ha hecho lo que existe para llamar mi atención,\nque quiere conquistarme y alegrar mi corazón...\n\n2\nMe dice que me ama\ncuando veo la cruz,\nsus manos extendidas\nasí tan grande es su amor...\nLo dicen las heridas\nde sus manos y pies\nEl dice que me ama\nuna y otra vez..."
    },
    {
        "title": "TÚ ESTÁS AQUÍ",
        "tone": "",
        "lyrics": "Aunque mis ojos no te puedan ver,\nTe puedo sentir,\nSé que estás aquí.\nAunque mis manos no pueden tocar\nTu rostro Señor;\nSé que estás aquí\n\nCoro:\nMi corazón puede sentir tu presencia,\nTú estás aquí, Tú estás aquí\nPuedo sentir tu majestad\nTú estás aquí, Tú estás aquí\nMi corazón puede mirar tu hermosura,\nTú estás aquí, Tú estás aquí\nPuedo sentir tu gran amor,\nTú estás aquí, Tú estás aquí\n\n(Se repite todo)"
    },
    {
        "title": "SI NO CUESTA NADA",
        "tone": "",
        "lyrics": "1\nSi no cuesta nada,\nSolo dos palabras,\n\"Te quiero\" y nada más\nTe quiero de verdad\nJesús, Jesús\nPorque la mereces\nY te pertenece\nLa gloria solo a Ti\nLa gloria que hay en Tí\nSeñor, Señor\n\nCoro:\nPorque Tú, sol de la mañana\nDas vida, donde no existe nada\nY vienes al hombre que es malo\nY le amas, y le amas\nSiendo Tú el rey de la gloria\nMoriste para darme victoria\nHoy vives y llevo en mi canto\nTú historia.\n\n2\nEn mi pensamiento\nY en cualquier momento\nTe alabo solo a Ti,\nTe alabo tanto así,\nJesús, Jesús\nY Tú estás presente\nCuando anhelo verte\nY estas dentro de mí\nY estas muy junto a mí\nSeñor, Señor"
    },
    {
        "title": "FUE POR MÍ",
        "tone": "",
        "lyrics": "1\n¿Que significa aquella Cruz?\nes más que una canción\nmás que un emblema de paz y amor\nes la ¡libertad!\ndel pecado y la maldad\ny su sangre derramada nos lavó.\n\n2\nSobre esa cruz Jesús murió\nMostrándonos su amor\namor que nadie imaginó\nesa hermosa cruz\nyo jamás despreciaré\npues en ella mis pecados él borró.\n\nPuente:\nEs la cruz la muestra del amor\nque tuvo Dios por mi\ncuando el Señor su hijo envió\nsu sangre derramó\ny fue por mi, fue por mi\nCristo en la cruz murió por mi.\n\nCoro:\nFue por mi, fue por mi\nCristo en la cruz murió por mi\nfue por mi, fue por mi\nCristo en la cruz murió por mi."
    },
    {
        "title": "MAGNÍFICO",
        "tone": "",
        "lyrics": "1\n¿Quien se compara a Ti?\nQue acomodaste las estrellas\n¿quien calmó la tempestad?\nQue estalló sobre mí\n¿Quien se compara a Ti?\nQue traes el amanecer\nLa esperanza del mundo\nEstá segura en tu amor\n\nCoro:\nTu eres magnífico, hermoso Dios\nEterno, glorioso Cristo, nadie se comparará\nA ti Cristo\n\n2\nAl atardecer\nInspiras cantos de gozo\nAl amanacer\nTus hijos te alabarán\n\nCoro:\nCristo, nunca nadie se comparará\nA ti Cristo, Cristo\nNadie se comparará\n\nFinal:\nA ti Cristo, nadie se comparará\nA ti, Cristo, a tí Cristo\nNadie se comparará\nA ti, Cristo."
    },
    {
        "title": "NECESITO DE TI, SEÑOR",
        "tone": "",
        "lyrics": "1\nQuien entenderá el gran amor de mi Señor\nComo en su voluntad, me quiso amar,\nSin condición.\nTal vez miro mi corazón, mi ruina y\nGrande perdición.\nDios sin ti, nada soy\n\nCoro:\nNecesito Señor, cada día de Ti,\nNecesito tu amor para vivir,\nQue haría mi Dios si un día Tu, me faltaras\nNo te apartes de mi, llena mi corazón\nSacia todo mi ser, buen Jesús\nCon tu presencia\n\n2\nPríncipe de paz, majestuoso gran Señor\nMi alma anhela estar, a tu lado\nSalvador,\nY ante ti me humillaré, proclamaré\nCon devoción\nQue por ti, salvo soy"
    },
    {
        "title": "REYES SE INCLINARÁN",
        "tone": "",
        "lyrics": "1\nSe mofan de él, a fábulas igualan su palabra\nPrueban mi fe, se burlan, se alejan de mí\nRechazo inútil es, más firme es la verdad\nQue su difamación, nada cambiará aún\nEn éste mismo día, si el padre quiere.\n\nCoro:\nReyes se inclinarán\nNaciones han de adorarle\nY cada lengua dirá\nQue Cristo es el Señor\n//Cristo es el Señor//\n\n2\nEl mundo actual,\nse hunde en vergüenza degradante\nEl pecador prospera, parece tener paz\nMás tú permaneces fiel, justicia pronto habrá\nY cada sacrificio aquí, por causa de Jesús\nSerá recompensado ahí,\ncuando al nombre de Cristo."
    },
    {
        "title": "TE ADORO",
        "tone": "",
        "lyrics": "1\nEn mi necesidad\nPagaste tú por mí\nY en tu amor\nMe hiciste libre al fin\nAhora no soy igual\nYa no hay tristeza en mí\nAhora y siempre te alabaré\n\nCoro:\n//Te adoro//\nMi Salvador, mi Príncipe de Paz\n//Te adoro//\nBajaste al mundo por salvarme a mí\nTe adoro mi Jesús.\n\n2\nEl fue la ofrenda que\nLibró mi corazón\nClavado por\nMis culpas y error\nJamás podré pagar\nLo inmenso de su amor\nAhora y siempre le adoraré"
    },
    {
        "title": "MIRÉ A JESÚS",
        "tone": "",
        "lyrics": "1\nMire a Jesús\ny contemplé yo su mirada,\nmiré su rostro entristecido\nque me miraba.\nUna corona de espinas en su frente,\ny ví sus manos enclavadas\nen un madero...\n\nCoro:\nEl ya pagó la deuda que yo aún tenía\ny El sufriendo en dura cruz\npor mis pecados.\nA mi me resta serle fiel,\ntambién amarle,\nal Rey de gloria,\nserviré hasta la muerte\n\n2\nLeeré en sus ojos:\n\"Hijo mio, anda y cuenta\nque grandes cosas ha hecho Dios,\nel Rey de gloria\".\nMe ha perdonado y me ha lavado\nen su sangre.\nY todo eso en la cruz\nlo ha pagado..."
    },
    {
        "title": "MORA EN MI VIDA",
        "tone": "",
        "lyrics": "1\nHoy te siento Señor\nmuy dentro de mi vida,\ny no puedo dejar de sentirte otra vez,\nmientras tenga yo vida\nPorque grande...\nEs el poder\nque rebosa en mi corazón\nY con el me haces ver\nque no vuelva a caer,\n¡¡Tu me cuidas, Señor!!\n\nCoro:\nGrande precio pagaste\nen esa cruz,\npor mi un día.\nCon tu sangre lavaste\ncon tus llagas curaste mis heridas\n¿Como he de pensar\nen quererte soltar,\nsi Tu me guías?.\nPorque eres mi razón de vivir,\nes por eso que te quiero decir:\n¡Mora en mi Vida!\n\n2\nReconozco Señor,\nque tu amor garantiza\nPaz y seguridad,\nque no podía hallar,\npues, no te conocía\nA mi encuentro...\nLlegaste Tú,\nme cubriste en tu manto de amor.\nMe compraste Señor,\ncon la sangre que hoy\nlava mi corazón"
    },
    {
        "title": "NADA ME APARTARÁ",
        "tone": "",
        "lyrics": "1\nSiento en mi Corazón una gran necesidad,\nSe que Tú puedes llenar, junto a Ti quiero estar,\nEn tu pecho descansar,\nNo permitas que me aleje de tu presencia...\n\n2\n...Renueva mi vida Señor, ya no quiero más errar,\nNi en soledad morar, con amor me rescataste,\nY mis fuerzas renovaste,\n¡Tú eres mi refugio, no me dejes!...\n\nCoro:\n...Ni tormentas, ni vientos me apartarán\nPues con fuerzas Señor, me sostendrás\nAunque esté en lo profundo me levantarás\nSeguro estoy contigo, ¡Nada temeré!\nSe que todas mis lágrimas enjugarás\nY con brazos abiertos me recibirás\nCon amor me dirás, no sufras más\nHaz vencido y conmigo estarás...\n\nPuente:\nNi lo alto, ni lo bajo me apartará\nSeguro estoy contigo, ¡Nada Temeré!\nSolista:\nNi tormentas me apartarán de Jesús...\n\nFinal:\n//Haz vencido y conmigo//\n¡Haz vencido y conmigo estarás!"
    },
    {
        "title": "NO SÉ PORQUE",
        "tone": "",
        "lyrics": "1\nNo se porque,\nSeñor, Tu me tocaste\nno se porque\nen mi Tu te fijaste,\npero si se,\nque es grande tu amor\npor mi.\nMi corazón\nesta agradecido,\nmi corazón\nesta a Ti rendido,\ncontigo siempre\nquiero Señor estar.\n\nCoro:\n//Porque fuera de Ti,\nnada deseo\nen la tierra,\nTu presencia es mas hermosa,\nque cualquier cosa//\n\n2\nTu eres Señor,\nmi gozo y mi alegria,\nTu estás Señor,\nconmigo todo el dia,\nen Ti yo siempre\nquiero Señor estar.\nMi corazón\nesta agradecido,\nmi corazón\nesta a Ti rendido,\ncontigo siempre\nquiero Señor estar.\n\nPuente:\n//Me has librado de la muerte,\nme has dado nueva vida,\ndesataste mi tristeza,\nme ceñiste de alegría//\nPor tanto nunca callaré\na Ti cantaré,\nte alabaré\n¡Gloria Mía!\nCristo mi Señor\na Ti cantaré,\nte alabaré\n¡Gloria Mía!"
    },
    {
        "title": "NO TE DEJARÉ",
        "tone": "",
        "lyrics": "1\nDios suplirá todo lo que falte\nen la grandeza de su gloria,\nProsperará siempre mi alma\ny me dará la victoria,\nAunque rujan las huestes malignas\nEl estará conmigo,\nJehová la fortaleza de los siglos\nes mi mejor amigo\n\nCoro:\nNo te dejaré, no te dejaré\nde dia ni de noche,\n||No te dejaré||\n\n2\nJehova es mi fuerte castillo\nmi amparo es la roca de Horeb,\nSu voz como rios de agua\nsacia por siempre mi sed...\nJehová cambia el llanto por gozo,\nAl triste le ofrece la paz.\nAl ciego dá vista y al cojo levanta\ny salvación El les dá"
    },
    {
        "title": "NO TEMAS",
        "tone": "",
        "lyrics": "Coro:\nNo temas, confía\nvictoria te dará el Señor\nEl es tu protector, Jehová tu Salvador\ntu Dios de amor, tu salvación\n\n1\nNo temas, el Señor está contigo\nEl es tu mejor amigo,\nEl jamás te dejará\nNo temas, aunque fuerte sople el viento\ny te turben pensamientos\nel Señor te sostendrá\nNo temas si el infierno se levanta\nes Jehová el que te guarda\nel jamás se dormira\n\n2\nNo temas, Jehová es tu castillo\nfortaleza de tu vida\nes tu luz tu salvación\nNo temas si la cruel desesperanza\ncon su sombra te abraza...\nel Señor te sostendrá\nNo temas si luchada está tu alma\nes Jehová el que te guarda\nEl jamás se dormirá..."
    },
    {
        "title": "OH SEÑOR, CREO EN TI",
        "tone": "",
        "lyrics": "1\nQuize huir de Ti, pero tu mano fue sobre mi\nal saber que tu camino iba a dejar.\nComo hombre fui a buscar\nmejor vida, mejor vida para mi\n\nCoro:\nY he recorrido largos senderos al caminar\ny te puedo decir:\nQue no hay mejor amor, mejor amor que el de Dios.\nCreo en ti, porque Tu eres mi esperanza para vivir,\nporque me hiciste a tu imagen, oh Señor,\nporque Tu eres mis pasos al caminar...\nCreo en Ti, porque Tu eres mi voz al cantar,\nporque Tu eres mi boca al hablar,\nporque Tu eres mi mente al pensar.\nCreo en tí, creo en tí, oh Señor, creo en tí.\n\n2\nY ahora que pienso en los que quedan,\nen los que quedan sin salvación.\nQue pena me dá al saber\nque para ellos, la salvación también fué..."
    },
    {
        "title": "POR ESO CANTO",
        "tone": "",
        "lyrics": "1\nEn este mundo me encontraba,\nSin una explicación\nSin que nadie me escuchara\nY me diera su calor.\nCaminaba en tinieblas\nY mi Cristo se acercó.\nHoy conozco su grandeza\nY lo inmenso de su amor…\n\nCoro:\nPor eso canto, yo canto al amor de Cristo\nYo canto al hombre que me salvó\nY libertó, yo canto…\nPor eso canto y alzo mis manos al cielo,\nPara decir: \"Te Quiero, Te Amo, Te Alabo Señor,\nCon toda mi alma y ser…\"\n\n2\nEn este mundo caminaba\nSin paz y sin amor,\nSin ninguna esperanza\nA mi pobre corazón.\nAhora canto para Cristo,\nEs mi sola inspiración,\nHoy conozco su grandeza\nY lo inmenso de su amor…"
    },
    {
        "title": "PROMESA CUMPLIDA",
        "tone": "",
        "lyrics": "1\nCanto para agradecer\nsu infinito amor que a mi llegó.\nPienso en aquellos tiempos,\ncuando en mis comienzos\nsu voz me habló:\n\"Aunque vivas en pruebas\nte prometo bendición\";\nvoz que no cayó en tierra\ny su palabra fiel cumplió...\n\nCoro:\nCumplió su promesa, la cumplió,\nsentí en mi vida su amor.\nCumplió su promesa, no mintió,\nBendijo mi vida, promesa cumplida\n¡Gracias mi Dios!\n\n2\nLloro de gozo al cantar,\nme hace recordar lo que ayer fuí.\nMiro a mi alrededor y viene esa voz,\nla del Señor...:\n\"Dura es esta prueba, más Yo te sustentaré\ny al final de esta carrera,\nbendición en ti pondré\"...\n\n3\nRio porque un día más\npuedo contemplar su bendición.\nCristo a cada momento\nes el buen sustento en el dolor,\nAhora que el tiempo ha pasado\nmiro lo que recorrí,\nnunca fuí desamparado\ny solo me queda decir:"
    },
]

added = []
skipped = []
next_id = last_id + 1

for hymn in new_hymns:
    key = hymn['title'].strip().upper()
    if key in existing_titles:
        skipped.append(hymn['title'])
    else:
        hymn['id'] = next_id
        data.append(hymn)
        existing_titles.add(key)
        added.append(f"[{next_id}] {hymn['title']}")
        next_id += 1

with open('assets/json/special_hymns.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"✅ Agregados ({len(added)}):")
for t in added: print(f"   {t}")
print(f"\n⏭️  Omitidos por duplicados ({len(skipped)}):")
for t in skipped: print(f"   - {t}")
print(f"\nTotal cantos ahora: {len(data)}")
print(f"Último ID: {data[-1]['id']}")
print("\n⚠️  NOTA: 'RAZÓN DE MI VIDA' fue omitido porque el mensaje llegó truncado (incompleto).")
