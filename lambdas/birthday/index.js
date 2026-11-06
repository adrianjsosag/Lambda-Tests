exports.handler = async (event) => {
    const now = new Date();
    const year = now.getUTCFullYear();

    // Próximo 5 de enero a las 00:00 UTC (si ya pasó este año, el del siguiente)
    let target = Date.UTC(year, 0, 5);
    if (now.getTime() >= target) {
        target = Date.UTC(year + 1, 0, 5);
    }

    // ¿Hoy (en UTC) es 5 de enero?
    const isToday = now.getUTCMonth() === 0 && now.getUTCDate() === 5;

    // Calcular la diferencia en milisegundos
    const diffMs = target - now.getTime();

    // Convertir a días, horas, minutos y segundos
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((diffMs % (1000 * 60)) / 1000);

    const targetDate = new Date(target).toISOString().slice(0, 10); // "AAAA-01-05"

    const countdownMessage = isToday
        ? `¡Hoy es 5 de enero, feliz cumpleaños! 🎂 El próximo es en ${days} días, ${hours} horas, ${minutes} minutos y ${seconds} segundos`
        : `Faltan ${days} días, ${hours} horas, ${minutes} minutos y ${seconds} segundos para el 5 de enero 🎂`;

    console.log(countdownMessage);

    return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            target_date: targetDate,
            is_today: isToday,
            time_remaining: { days, hours, minutes, seconds },
            message: countdownMessage
        })
    };
};
