class ChatDokaRules extends GameRules;

var MutChatDokaBots ChatMut;

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> damageType, vector HitLocation)
{
    if (NextGameRules != None && NextGameRules.PreventDeath(Killed, Killer, damageType, HitLocation))
    {
        return true;
    }

    // Si un bot consigue una baja usando el Redeemer o el Ion Painter, festeja la explosion
    if (ChatMut != None && Killer != None && Bot(Killer) != None && Killed != None && Killed.Controller != Killer && damageType != None)
    {
        if (ClassIsChildOf(damageType, class'XWeapons.DamTypeRedeemer') || ClassIsChildOf(damageType, class'XWeapons.DamTypeIonBlast'))
        {
            ChatMut.TriggerUltimateKillChat(Bot(Killer));
        }
    }

    return false;
}

function ScoreKill(Controller Killer, Controller Killed)
{
    if (NextGameRules != None)
    {
        NextGameRules.ScoreKill(Killer, Killed);
    }

    if (ChatMut != None)
    {
        // Si muere un jugador humano, un bot aliado se burla de el mencionando su nombre
        if (Killed != None && PlayerController(Killed) != None)
        {
            ChatMut.TriggerHumanDeathTaunt(Killed);
        }
        else if (Killed != None && Bot(Killed) != None)
        {
            ChatMut.TriggerBotChat(Bot(Killed), 0.75);
        }
        else if (Bot(Killer) != None)
        {
            ChatMut.TriggerBotChat(Bot(Killer), 0.30);
        }
    }
}

function int NetDamage(int OriginalDamage, int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
    if (NextGameRules != None)
    {
        Damage = NextGameRules.NetDamage(OriginalDamage, Damage, injured, instigatedBy, HitLocation, Momentum, DamageType);
    }

    // Si un bot queda con poca vida tras recibir dano
    if (ChatMut != None && injured != None && Bot(injured.Controller) != None)
    {
        if (injured.Health > 0 && (injured.Health - Damage) > 0 && (injured.Health - Damage) < 40)
        {
            ChatMut.TriggerBotChat(Bot(injured.Controller), 0.45);
        }
    }

    return Damage;
}
